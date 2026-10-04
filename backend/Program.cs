using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using QuestPDF.Fluent;

QuestPDF.Settings.License = QuestPDF.Infrastructure.LicenseType.Community;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();
builder.Services.AddDbContext<KkcsDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));
var jwtSettings = builder.Configuration.GetSection("Jwt");
var jwtKey = jwtSettings["Key"] ?? throw new InvalidOperationException("JWT key belum dikonfigurasi.");
builder.Services.AddSingleton<JwtTokenService>();
builder.Services.AddScoped<SimpananService>();
builder.Services.AddScoped<JurnalService>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<AuditService>();
builder.Services.AddSingleton<MigrasiSignatureService>();
builder.Services.AddHostedService<SimpananBackgroundService>();
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
            ValidateIssuer = true,
            ValidIssuer = jwtSettings["Issuer"],
            ValidateAudience = true,
            ValidAudience = jwtSettings["Audience"],
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    });
builder.Services.AddAuthorization(options =>
{
    // Admin: operasional teknis sistem (akun, role, akses, konfigurasi) — juga otomatis bisa
    // mengakses semua yang bisa diakses Pengurus, karena "Pengurus" mengizinkan role Admin juga.
    options.AddPolicy("Admin", policy => policy.RequireRole("Admin"));
    // Pengurus: operasional bisnis koperasi (simpanan, pinjaman, katalog, E-RAT, laporan). Admin ikut lolos.
    options.AddPolicy("Pengurus", policy => policy.RequireRole("Admin", "Pengurus"));
});
builder.Services.AddCors(options =>
{
    options.AddPolicy("FlutterDevelopment", policy =>
        policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod().WithExposedHeaders("X-Total-Count", "X-Total-Simpanan", "X-Count-Aktif", "X-Count-Lunas", "X-Total-SisaPokok"));
});
// Backend jalan di belakang Nginx (reverse proxy) saat deploy — Nginx terima HTTPS dari luar lalu
// teruskan ke Kestrel via HTTP biasa di localhost. Tanpa ini, Kestrel mengira semua request HTTP
// murni dan UseHttpsRedirection() di bawah akan salah redirect / Request.Scheme salah di log audit.
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
});

var app = builder.Build();

KoperasiPdfHeader.Inisialisasi(app.Environment.WebRootPath ?? Path.Combine(app.Environment.ContentRootPath, "wwwroot"));

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseForwardedHeaders();
app.UseHttpsRedirection();
app.UseCors("FlutterDevelopment");
app.UseStaticFiles();
app.UseAuthentication();

// Token JWT menyimpan peran & status aktif pas login, dan tetap berlaku sampai 2 jam meski akunnya
// dinonaktifkan atau perannya diturunkan setelah itu. Cek ulang ke database di setiap request supaya
// perubahan status/peran langsung berlaku pada request berikutnya, bukan menunggu token kedaluwarsa.
app.Use(async (context, next) =>
{
    if (context.User.Identity?.IsAuthenticated == true)
    {
        var subject = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        var peranToken = context.User.FindFirstValue(ClaimTypes.Role);
        if (int.TryParse(subject, out var penggunaId))
        {
            var db = context.RequestServices.GetRequiredService<KkcsDbContext>();
            var status = await db.Pengguna.AsNoTracking()
                .Where(p => p.Id == penggunaId)
                .Select(p => new { p.Aktif, p.Peran })
                .FirstOrDefaultAsync();
            if (status is null || !status.Aktif || status.Peran != peranToken)
            {
                context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                await context.Response.WriteAsJsonAsync(new { message = "Sesi tidak lagi berlaku — akun dinonaktifkan atau perannya berubah. Silakan login ulang." });
                return;
            }
        }
    }
    await next();
});

app.UseAuthorization();

app.MapPost("/api/auth/register", async (RegisterRequest request, KkcsDbContext db, JwtTokenService tokenService) =>
{
    if (string.IsNullOrWhiteSpace(request.NamaLengkap) || string.IsNullOrWhiteSpace(request.NomorIndukKaryawan))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["pengguna"] = ["Nama lengkap dan NIK wajib diisi."]
        });
    }

    if (request.Password.Length < 8)
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["password"] = ["Password minimal 8 karakter."]
        });
    }

    var nik = request.NomorIndukKaryawan.Trim();
    if (nik.Length < 5)
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["nomorIndukKaryawan"] = ["NIK minimal 5 karakter."]
        });
    }

    if (await db.Pengguna.AnyAsync(pengguna => pengguna.NomorIndukKaryawan == nik))
    {
        return Results.Conflict(new { message = "NIK sudah terdaftar." });
    }

    var pengguna = new Pengguna
    {
        NamaLengkap = request.NamaLengkap.Trim(),
        NomorIndukKaryawan = nik,
        Email = string.IsNullOrWhiteSpace(request.Email) ? null : request.Email.Trim().ToLowerInvariant(),
        PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
        StatusKeanggotaan = "MenungguPersetujuan"
    };
    db.Pengguna.Add(pengguna);
    await db.SaveChangesAsync();

    return Results.Created($"/api/auth/me", new AuthResponse(
        tokenService.CreateToken(pengguna),
        ToUserResponse(pengguna)));
});

app.MapPost("/api/auth/login", async (LoginRequest request, KkcsDbContext db, JwtTokenService tokenService) =>
{
    const int BatasPercobaanGagal = 5;
    var durasiKunci = TimeSpan.FromMinutes(15);

    var nik = request.NomorIndukKaryawan.Trim();
    var pengguna = await db.Pengguna.FirstOrDefaultAsync(item => item.NomorIndukKaryawan == nik && item.Aktif);

    if (pengguna is not null && pengguna.TerkunciSampai is not null)
    {
        if (pengguna.TerkunciSampai > DateTime.UtcNow)
        {
            var sisaMenit = (int)Math.Ceiling((pengguna.TerkunciSampai.Value - DateTime.UtcNow).TotalMinutes);
            return Results.Json(new { message = $"Terlalu banyak percobaan login gagal. Akun terkunci sementara, coba lagi dalam {sisaMenit} menit." }, statusCode: 423);
        }
        // Waktu kunci sudah lewat — buka kunci otomatis di percobaan berikutnya.
        pengguna.TerkunciSampai = null;
        pengguna.PercobaanLoginGagal = 0;
    }

    if (pengguna is null || !BCrypt.Net.BCrypt.Verify(request.Password, pengguna.PasswordHash))
    {
        if (pengguna is not null)
        {
            pengguna.PercobaanLoginGagal += 1;
            if (pengguna.PercobaanLoginGagal >= BatasPercobaanGagal)
                pengguna.TerkunciSampai = DateTime.UtcNow.Add(durasiKunci);
            await db.SaveChangesAsync();
        }
        return Results.Unauthorized();
    }

    pengguna.PercobaanLoginGagal = 0;
    pengguna.TerkunciSampai = null;
    await db.SaveChangesAsync();

    return Results.Ok(new AuthResponse(
        tokenService.CreateToken(pengguna),
        ToUserResponse(pengguna)));
});

app.MapGet("/api/auth/me", async (ClaimsPrincipal principal, KkcsDbContext db) =>
{
    var subject = principal.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? principal.FindFirstValue(ClaimTypes.Name)
        ?? principal.FindFirstValue("sub");
    if (!int.TryParse(subject, out var penggunaId))
    {
        return Results.Unauthorized();
    }

    var pengguna = await db.Pengguna.AsNoTracking().FirstOrDefaultAsync(item => item.Id == penggunaId);
    return pengguna is null
        ? Results.NotFound()
        : Results.Ok(ToUserResponse(pengguna));
}).RequireAuthorization();

app.MapGet("/api/panduan/anggota/pdf", () =>
    Results.File(PanduanAnggotaPdf.Buat(), "application/pdf", "Manual-Book-Anggota-KKCS.pdf"))
    .RequireAuthorization();

app.MapGet("/api/admin/pengguna", async (KkcsDbContext db, HttpResponse response, int? halaman, int? ukuran) =>
{
    var query = db.Pengguna.AsNoTracking().OrderBy(pengguna => pengguna.NamaLengkap).AsQueryable();
    if (ukuran is > 0)
    {
        var total = await query.CountAsync();
        var ukuranHalaman = Math.Min(ukuran.Value, 200);
        var nomorHalaman = halaman is > 0 ? halaman.Value : 1;
        query = query.Skip((nomorHalaman - 1) * ukuranHalaman).Take(ukuranHalaman);
        response.Headers["X-Total-Count"] = total.ToString();
    }
    var data = await query
        .Select(pengguna => new AdminUserResponse(
            pengguna.Id,
            pengguna.NamaLengkap,
            pengguna.NomorIndukKaryawan,
            pengguna.Email,
            pengguna.Peran,
            pengguna.StatusKeanggotaan,
            pengguna.Aktif,
            pengguna.DibuatPada))
        .ToListAsync();
    return Results.Ok(data);
}).RequireAuthorization("Admin");

app.MapPatch("/api/admin/pengguna/{id:int}/status", async (int id, ToggleUserStatusRequest request, ClaimsPrincipal principal, KkcsDbContext db, AuditService audit) =>
{
    var pengguna = await db.Pengguna.FirstOrDefaultAsync(item => item.Id == id);
    if (pengguna is null) return Results.NotFound();
    if (pengguna.Peran == "Admin" && !request.Aktif)
    {
        var jumlahAdminAktif = await db.Pengguna.CountAsync(item => item.Peran == "Admin" && item.Aktif);
        if (jumlahAdminAktif <= 1) return Results.BadRequest(new { message = "Tidak bisa menonaktifkan satu-satunya akun Admin yang aktif." });
    }
    pengguna.Aktif = request.Aktif;
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Akun", request.Aktif ? "Aktifkan" : "Nonaktifkan",
        $"{(request.Aktif ? "Mengaktifkan" : "Menonaktifkan")} akun {pengguna.NamaLengkap} (NIK {pengguna.NomorIndukKaryawan}).", pengguna.Id);
    return Results.Ok(new AdminUserResponse(
        pengguna.Id,
        pengguna.NamaLengkap,
        pengguna.NomorIndukKaryawan,
        pengguna.Email,
        pengguna.Peran,
        pengguna.StatusKeanggotaan,
        pengguna.Aktif,
        pengguna.DibuatPada));
}).RequireAuthorization("Admin");

app.MapPatch("/api/admin/pengguna/{id:int}/peran", async (int id, PeranRequest request, ClaimsPrincipal principal, KkcsDbContext db, AuditService audit) =>
{
    var peranValid = new[] { "Admin", "Pengurus", "Anggota" };
    if (!peranValid.Contains(request.Peran)) return Results.BadRequest(new { message = "Peran harus Admin, Pengurus, atau Anggota." });
    var pengguna = await db.Pengguna.FirstOrDefaultAsync(item => item.Id == id);
    if (pengguna is null) return Results.NotFound();
    if (pengguna.Peran == "Admin" && request.Peran != "Admin")
    {
        var jumlahAdmin = await db.Pengguna.CountAsync(item => item.Peran == "Admin" && item.Aktif);
        if (jumlahAdmin <= 1) return Results.BadRequest(new { message = "Tidak bisa mengubah peran satu-satunya Admin. Tunjuk Admin lain terlebih dahulu." });
    }
    var peranLama = pengguna.Peran;
    pengguna.Peran = request.Peran;
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Akun", "UbahPeran",
        $"Mengubah peran {pengguna.NamaLengkap} (NIK {pengguna.NomorIndukKaryawan}) dari {peranLama} menjadi {pengguna.Peran}.", pengguna.Id,
        new { peranLama, peranBaru = pengguna.Peran });
    return Results.Ok(new AdminUserResponse(
        pengguna.Id, pengguna.NamaLengkap, pengguna.NomorIndukKaryawan, pengguna.Email,
        pengguna.Peran, pengguna.StatusKeanggotaan, pengguna.Aktif, pengguna.DibuatPada));
}).RequireAuthorization("Admin");

app.MapPost("/api/admin/pengguna/{id:int}/reset-akses", async (int id, ClaimsPrincipal principal, KkcsDbContext db, AuditService audit) =>
{
    var pengguna = await db.Pengguna.FirstOrDefaultAsync(item => item.Id == id);
    if (pengguna is null) return Results.NotFound();
    var passwordSementara = BuatPasswordSementara();
    pengguna.PasswordHash = BCrypt.Net.BCrypt.HashPassword(passwordSementara);
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Akun", "ResetAkses",
        $"Mereset akses login {pengguna.NamaLengkap} (NIK {pengguna.NomorIndukKaryawan}).", pengguna.Id);
    return Results.Ok(new
    {
        message = $"Akses {pengguna.NamaLengkap} berhasil direset. Sampaikan password sementara ini secara langsung/aman — anggota disarankan segera menggantinya.",
        passwordSementara
    });
}).RequireAuthorization("Admin");

// ── Pengurus: Dashboard utama — ringkasan lintas modul untuk pengurus/admin sekali lihat ─────
app.MapGet("/api/admin/dashboard/ringkasan", async (KkcsDbContext db) =>
{
    var hariIni = DateTime.UtcNow.Date;
    var awalBulan = new DateTime(hariIni.Year, hariIni.Month, 1);
    var awalTahun = new DateTime(hariIni.Year, 1, 1);

    // Anggota
    var totalAnggotaAktif = await db.Pengguna.CountAsync(p => p.StatusKeanggotaan == "Aktif" && p.Aktif);
    var pendaftaranMenunggu = await db.Pengguna.CountAsync(p => p.StatusKeanggotaan == "MenungguPersetujuan");

    // Akuntansi (dihitung langsung dari buku besar, selalu sinkron dengan jurnal)
    var neraca = await AkuntansiReportService.HitungNeracaAsync(db, hariIni);
    var labaRugiTahunIni = await AkuntansiReportService.HitungLabaRugiAsync(db, awalTahun, hariIni);
    var labaRugiBulanIni = await AkuntansiReportService.HitungLabaRugiAsync(db, awalBulan, hariIni);

    // Simpanan
    // Pokok & Wajib diambil dari buku besar agar sama dengan Neraca; tabel Simpanan per anggota tidak memuat
    // saldo ex-anggota yang sudah keluar namun masih tercatat di neraca.
    decimal SaldoBuku(string kode) => neraca.Ekuitas.FirstOrDefault(a => a.Kode == kode)?.Saldo ?? 0;
    var totalSimpananPerJenis = await db.Simpanan.Include(s => s.JenisSimpanan)
        .GroupBy(s => s.JenisSimpanan.Kode)
        .Select(g => new { Kode = g.Key, Total = g.Sum(s => s.Saldo) })
        .ToListAsync();
    decimal SaldoJenis(string kode) => totalSimpananPerJenis.FirstOrDefault(x => x.Kode == kode)?.Total ?? 0;
    var saldoPokok = SaldoBuku(KodeAkun.SimpananPokok);
    var saldoWajib = SaldoBuku(KodeAkun.SimpananWajib);
    var totalBerjangkaAktif = await db.SimpananBerjangka.Where(b => b.Status == "Aktif" || b.Status == "JatuhTempo").SumAsync(b => (decimal?)b.Nominal) ?? 0;
    var totalSimpananSemua = saldoPokok + saldoWajib + SaldoJenis("SUKARELA") + totalBerjangkaAktif;
    var wajibMenunggu = await db.TagihanWajib.CountAsync(t => t.Status == "Ditagih");
    var sukarelaMenunggu = await db.TransaksiSukarela.CountAsync(t => t.Status == "Diajukan");
    var berjangkaMenunggu = await db.SimpananBerjangka.CountAsync(b => b.Status == "Diajukan" || b.PencairanDiajukan);

    // Pinjaman
    var pinjamanAktifCount = await db.Pinjaman.CountAsync(p => p.Status == "Aktif");
    var totalSisaPokok = await db.Pinjaman.Where(p => p.Status == "Aktif").SumAsync(p => (decimal?)p.SisaPokok) ?? 0;
    var pengajuanPinjamanMenunggu = await db.PengajuanPinjaman.CountAsync(p => p.Status == "Diajukan");
    var pembayaranPinjamanMenunggu = await db.PembayaranPinjaman.CountAsync(p => p.Status == "Diajukan");

    // Katalog
    var titipanMenunggu = await db.Produk.CountAsync(p => p.Status == "MenungguPersetujuan");
    var pembelianMenunggu = await db.PembelianProduk.CountAsync(p => p.Status == "Diajukan");
    var tagihanKreditBelumLunas = await db.TagihanKredit.Where(t => t.Status != "Lunas").SumAsync(t => (decimal?)t.Total) ?? 0;

    // Tren 6 bulan terakhir (pendapatan vs beban) untuk grafik ringkas.
    var trenBulanan = new List<DashboardTrenBulanan>();
    var namaBulan = new[] { "Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des" };
    for (var i = 5; i >= 0; i--)
    {
        var bulan = new DateTime(awalBulan.Year, awalBulan.Month, 1).AddMonths(-i);
        var akhirBulan = bulan.AddMonths(1).AddDays(-1);
        var lr = await AkuntansiReportService.HitungLabaRugiAsync(db, bulan, akhirBulan);
        trenBulanan.Add(new DashboardTrenBulanan($"{namaBulan[bulan.Month - 1]} {bulan.Year % 100}", lr.TotalPendapatan, lr.TotalBeban, lr.LabaBersih));
    }

    // SHU tahun terakhir yang difinalisasi
    var shuTerakhir = await db.ShuRun.AsNoTracking().OrderByDescending(s => s.Tahun)
        .Select(s => new DashboardShuTerakhir(s.Tahun, s.TotalShu, s.TotalShuNeto, s.Rincian.Count, s.DifinalisasiPada))
        .FirstOrDefaultAsync();

    // Payroll periode berjalan
    var payroll = await BuatRekapPayroll(db, hariIni.ToString("yyyy-MM"));

    // Audit trail — aktivitas terbaru untuk pemantauan cepat
    var auditHariIni = await db.AuditLog.CountAsync(a => a.WaktuUtc.Date == hariIni);
    var auditAktivitasTerbaru = await db.AuditLog.AsNoTracking().OrderByDescending(a => a.Id).Take(6)
        .Select(a => new DashboardAktivitas(a.WaktuUtc, a.PelakuNama, a.Modul, a.Aksi, a.Ringkasan))
        .ToListAsync();

    var totalMenunggu = pendaftaranMenunggu + wajibMenunggu + sukarelaMenunggu + berjangkaMenunggu
        + pengajuanPinjamanMenunggu + pembayaranPinjamanMenunggu + titipanMenunggu + pembelianMenunggu;

    return Results.Ok(new DashboardRingkasanResponse(
        totalAnggotaAktif, pendaftaranMenunggu,
        totalSimpananSemua, saldoPokok, saldoWajib, SaldoJenis("SUKARELA"), totalBerjangkaAktif,
        wajibMenunggu, sukarelaMenunggu, berjangkaMenunggu,
        pinjamanAktifCount, totalSisaPokok, pengajuanPinjamanMenunggu, pembayaranPinjamanMenunggu,
        titipanMenunggu, pembelianMenunggu, tagihanKreditBelumLunas,
        neraca.TotalAset, neraca.TotalLiabilitas, neraca.TotalEkuitas, neraca.Selisih,
        labaRugiTahunIni.TotalPendapatan, labaRugiTahunIni.TotalBeban, labaRugiTahunIni.LabaBersih,
        labaRugiBulanIni.LabaBersih,
        trenBulanan, shuTerakhir,
        payroll.TotalPotongan, payroll.Baris.Count,
        auditHariIni, auditAktivitasTerbaru,
        totalMenunggu));
}).RequireAuthorization("Pengurus");

// ── Admin: Audit trail — jejak digital perubahan data sensitif & persetujuan ─
app.MapGet("/api/admin/audit-log", async (KkcsDbContext db, string? modul, string? aksi, int? penggunaId, DateTime? dari, DateTime? sampai, string? cari, int? halaman, int? ukuran) =>
{
    var query = db.AuditLog.AsNoTracking().AsQueryable();
    if (!string.IsNullOrWhiteSpace(modul)) query = query.Where(item => item.Modul == modul);
    if (!string.IsNullOrWhiteSpace(aksi)) query = query.Where(item => item.Aksi == aksi);
    if (penggunaId.HasValue) query = query.Where(item => item.PelakuId == penggunaId);
    if (dari.HasValue) query = query.Where(item => item.WaktuUtc >= dari.Value);
    if (sampai.HasValue) query = query.Where(item => item.WaktuUtc <= sampai.Value);
    if (!string.IsNullOrWhiteSpace(cari))
    {
        var needle = cari.Trim();
        query = query.Where(item => item.Ringkasan.Contains(needle) || item.PelakuNama.Contains(needle));
    }

    var total = await query.CountAsync();
    var ukuranHalaman = ukuran is > 0 and <= 200 ? ukuran.Value : 50;
    var nomorHalaman = halaman is > 0 ? halaman.Value : 1;
    var data = await query.OrderByDescending(item => item.WaktuUtc)
        .Skip((nomorHalaman - 1) * ukuranHalaman).Take(ukuranHalaman)
        .Select(item => new AuditLogResponse(
            item.Id, item.WaktuUtc, item.PelakuId, item.PelakuNama, item.PelakuPeran,
            item.Modul, item.Aksi, item.EntitasId, item.Ringkasan, item.Detail, item.AlamatIp))
        .ToListAsync();

    return Results.Ok(new { total, halaman = nomorHalaman, ukuran = ukuranHalaman, data });
}).RequireAuthorization("Admin");

app.MapGet("/api/admin/audit-log/modul", async (KkcsDbContext db) =>
    Results.Ok(await db.AuditLog.AsNoTracking().Select(item => item.Modul).Distinct().OrderBy(item => item).ToListAsync()))
    .RequireAuthorization("Admin");

// ── Admin: Audit trail level DATABASE — tercatat trigger SQL Server, mencakup akses lewat dBeaver/SSMS
// langsung (bukan cuma lewat API). Lihat migrasi TambahDbAuditTrail & TambahVerifikasiDbAuditChain. ────
app.MapGet("/api/admin/audit-log/db", async (KkcsDbContext db, string? tabel, DateTime? dari, DateTime? sampai, string? cari, int? halaman, int? ukuran) =>
{
    var query = db.DbAuditLog.AsNoTracking().AsQueryable();
    if (!string.IsNullOrWhiteSpace(tabel)) query = query.Where(item => item.Tabel == tabel);
    if (dari.HasValue) query = query.Where(item => item.WaktuUtc >= dari.Value);
    if (sampai.HasValue) query = query.Where(item => item.WaktuUtc <= sampai.Value);
    if (!string.IsNullOrWhiteSpace(cari))
    {
        var needle = cari.Trim();
        query = query.Where(item => item.KunciPrimer.Contains(needle) || item.DbLogin.Contains(needle));
    }

    var total = await query.CountAsync();
    var ukuranHalaman = ukuran is > 0 and <= 200 ? ukuran.Value : 50;
    var nomorHalaman = halaman is > 0 ? halaman.Value : 1;
    var data = await query.OrderByDescending(item => item.Id)
        .Skip((nomorHalaman - 1) * ukuranHalaman).Take(ukuranHalaman)
        .ToListAsync();

    return Results.Ok(new { total, halaman = nomorHalaman, ukuran = ukuranHalaman, data });
}).RequireAuthorization("Admin");

app.MapGet("/api/admin/audit-log/db/tabel", async (KkcsDbContext db) =>
    Results.Ok(await db.DbAuditLog.AsNoTracking().Select(item => item.Tabel).Distinct().OrderBy(item => item).ToListAsync()))
    .RequireAuthorization("Admin");

app.MapGet("/api/admin/audit-log/db/verifikasi", async (KkcsDbContext db) =>
{
    var bermasalah = await db.Database
        .SqlQueryRaw<BarisRantaiBermasalah>("EXEC dbo.sp_VerifikasiDbAuditChain")
        .ToListAsync();
    return Results.Ok(new
    {
        utuh = bermasalah.Count == 0,
        jumlahBermasalah = bermasalah.Count,
        message = bermasalah.Count == 0
            ? "Rantai hash audit database utuh — tidak ada indikasi baris log diedit/dihapus di luar jalur normal."
            : $"PERINGATAN: {bermasalah.Count} baris log audit database terindikasi diubah/tidak konsisten dengan rantai hash-nya.",
        baris = bermasalah
    });
}).RequireAuthorization("Admin");

// ── Admin: Impor/Ekspor massal data anggota (CSV) ────────────────────────────
app.MapGet("/api/admin/pengguna/ekspor", async (KkcsDbContext db) =>
{
    var data = await db.Pengguna.AsNoTracking().OrderBy(item => item.NamaLengkap).ToListAsync();
    var sb = new StringBuilder();
    sb.AppendLine("NIK,Nama,Email,Telepon,Alamat,Peran,StatusKeanggotaan,Aktif,DibuatPada");
    foreach (var item in data)
    {
        sb.AppendLine(string.Join(",",
            CsvHelper.Escape(item.NomorIndukKaryawan),
            CsvHelper.Escape(item.NamaLengkap),
            CsvHelper.Escape(item.Email),
            CsvHelper.Escape(item.NomorTelepon),
            CsvHelper.Escape(item.Alamat),
            CsvHelper.Escape(item.Peran),
            CsvHelper.Escape(item.StatusKeanggotaan),
            item.Aktif ? "true" : "false",
            item.DibuatPada.ToString("yyyy-MM-dd")));
    }
    return Results.File(CsvHelper.ToUtf8CsvBytes(sb.ToString()), "text/csv", $"anggota-{DateTime.UtcNow:yyyyMMdd}.csv");
}).RequireAuthorization("Admin");

app.MapPost("/api/admin/pengguna/impor", async (HttpRequest request, KkcsDbContext db) =>
{
    if (!request.HasFormContentType) return Results.BadRequest(new { message = "Kirim sebagai multipart/form-data." });
    var form = await request.ReadFormAsync();
    var file = form.Files["file"];
    if (file is null || file.Length == 0) return Results.BadRequest(new { message = "File CSV wajib diunggah." });
    if (file.Length > 5 * 1024 * 1024) return Results.BadRequest(new { message = "Ukuran file maksimal 5 MB." });

    string konten;
    using (var reader = new StreamReader(file.OpenReadStream(), Encoding.UTF8, true))
    {
        konten = await reader.ReadToEndAsync();
    }

    var baris = CsvHelper.Parse(konten);
    if (baris.Count == 0) return Results.BadRequest(new { message = "File CSV kosong atau format kolom tidak dikenali." });

    var peranValid = new[] { "Admin", "Pengurus", "Anggota" };
    var statusValid = new[] { "MenungguPersetujuan", "Aktif", "Ditolak" };
    var diperbarui = new List<string>();
    var dilewati = new List<string>();
    var galat = new List<string>();

    static string? Ambil(Dictionary<string, string> row, params string[] kunci)
    {
        foreach (var k in kunci)
        {
            if (row.TryGetValue(k, out var nilai) && !string.IsNullOrWhiteSpace(nilai)) return nilai.Trim();
        }
        return null;
    }

    var nomorBaris = 1;
    foreach (var row in baris)
    {
        nomorBaris++;
        var nik = Ambil(row, "NIK", "NomorIndukKaryawan");
        if (string.IsNullOrWhiteSpace(nik)) { galat.Add($"Baris {nomorBaris}: kolom NIK kosong."); continue; }

        var pengguna = await db.Pengguna.FirstOrDefaultAsync(item => item.NomorIndukKaryawan == nik);
        if (pengguna is null) { dilewati.Add(nik); continue; }

        var nama = Ambil(row, "Nama", "NamaLengkap");
        if (nama is not null) pengguna.NamaLengkap = nama;

        if (row.ContainsKey("Email")) pengguna.Email = string.IsNullOrWhiteSpace(row["Email"]) ? null : row["Email"].Trim().ToLowerInvariant();

        var telepon = Ambil(row, "Telepon", "NomorTelepon");
        if (row.ContainsKey("Telepon") || row.ContainsKey("NomorTelepon")) pengguna.NomorTelepon = telepon;

        if (row.ContainsKey("Alamat")) pengguna.Alamat = string.IsNullOrWhiteSpace(row["Alamat"]) ? null : row["Alamat"].Trim();

        var peran = Ambil(row, "Peran");
        if (peran is not null)
        {
            var cocok = peranValid.FirstOrDefault(p => p.Equals(peran, StringComparison.OrdinalIgnoreCase));
            if (cocok is null) galat.Add($"Baris {nomorBaris} ({nik}): Peran '{peran}' tidak valid.");
            else pengguna.Peran = cocok;
        }

        var status = Ambil(row, "StatusKeanggotaan", "Status");
        if (status is not null)
        {
            var cocok = statusValid.FirstOrDefault(s => s.Equals(status, StringComparison.OrdinalIgnoreCase));
            if (cocok is null) galat.Add($"Baris {nomorBaris} ({nik}): StatusKeanggotaan '{status}' tidak valid.");
            else pengguna.StatusKeanggotaan = cocok;
        }

        var aktifRaw = Ambil(row, "Aktif");
        if (aktifRaw is not null)
        {
            var lower = aktifRaw.ToLowerInvariant();
            if (lower is "true" or "1" or "ya" or "aktif") pengguna.Aktif = true;
            else if (lower is "false" or "0" or "tidak" or "nonaktif") pengguna.Aktif = false;
            else galat.Add($"Baris {nomorBaris} ({nik}): nilai Aktif '{aktifRaw}' tidak dikenali.");
        }

        diperbarui.Add(nik);
    }

    await db.SaveChangesAsync();
    return Results.Ok(new
    {
        message = $"{diperbarui.Count} anggota diperbarui, {dilewati.Count} NIK tidak ditemukan.",
        diperbarui = diperbarui.Count,
        dilewati,
        galat
    });
}).RequireAuthorization("Admin").DisableAntiforgery();

// ── Anggota: ganti password sendiri (self-service) — beda dari reset akses oleh Admin, di sini
// pengguna harus tahu password lamanya sendiri. Lihat juga POST /api/admin/pengguna/{id}/reset-akses.
app.MapPost("/api/auth/ganti-password", async (ClaimsPrincipal principal, GantiPasswordRequest request, KkcsDbContext db, AuditService audit) =>
{
    var pengguna = await FindCurrentUser(principal, db);
    if (pengguna is null) return Results.Unauthorized();

    if (string.IsNullOrWhiteSpace(request.PasswordLama) || !BCrypt.Net.BCrypt.Verify(request.PasswordLama, pengguna.PasswordHash))
    {
        return Results.BadRequest(new { message = "Password saat ini salah." });
    }
    if (string.IsNullOrWhiteSpace(request.PasswordBaru) || request.PasswordBaru.Length < 8)
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["passwordBaru"] = ["Password baru minimal 8 karakter."]
        });
    }
    if (BCrypt.Net.BCrypt.Verify(request.PasswordBaru, pengguna.PasswordHash))
    {
        return Results.BadRequest(new { message = "Password baru tidak boleh sama dengan password saat ini." });
    }

    pengguna.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.PasswordBaru);
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Akun", "GantiPassword", $"{pengguna.NamaLengkap} (NIK {pengguna.NomorIndukKaryawan}) mengganti password sendiri.", pengguna.Id);
    return Results.Ok(new { message = "Password berhasil diganti." });
}).RequireAuthorization();

app.MapPut("/api/auth/profile", async (ClaimsPrincipal principal, ProfileRequest request, KkcsDbContext db) =>
{
    var pengguna = await FindCurrentUser(principal, db);
    if (pengguna is null)
    {
        return Results.Unauthorized();
    }

    if (string.IsNullOrWhiteSpace(request.NamaLengkap))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["namaLengkap"] = ["Nama lengkap wajib diisi."]
        });
    }

    pengguna.NamaLengkap = request.NamaLengkap.Trim();
    pengguna.Email = string.IsNullOrWhiteSpace(request.Email) ? null : request.Email.Trim().ToLowerInvariant();
    pengguna.NomorTelepon = string.IsNullOrWhiteSpace(request.NomorTelepon) ? null : request.NomorTelepon.Trim();
    pengguna.Alamat = string.IsNullOrWhiteSpace(request.Alamat) ? null : request.Alamat.Trim();
    await db.SaveChangesAsync();
    return Results.Ok(ToUserResponse(pengguna));
}).RequireAuthorization();

app.MapPost("/api/auth/profile/photo", async (ClaimsPrincipal principal, IFormFile file, KkcsDbContext db, IWebHostEnvironment environment) =>
{
    var pengguna = await FindCurrentUser(principal, db);
    if (pengguna is null)
    {
        return Results.Unauthorized();
    }

    if (file.Length == 0 || file.Length > 5 * 1024 * 1024)
    {
        return Results.BadRequest(new { message = "Ukuran foto wajib lebih dari 0 dan maksimal 5 MB." });
    }

    var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".webp" };
    var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
    if (!allowedExtensions.Contains(extension) || !file.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
    {
        return Results.BadRequest(new { message = $"Format foto harus JPG, PNG, atau WEBP. File: {extension}, Content-Type: {file.ContentType}" });
    }

    var webRoot = environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot");
    var uploadDirectory = Path.Combine(webRoot, "uploads", "profile");
    Directory.CreateDirectory(uploadDirectory);
    var fileName = $"{Guid.NewGuid():N}{extension}";
    var filePath = Path.Combine(uploadDirectory, fileName);
    await using (var stream = File.Create(filePath))
    {
        await file.CopyToAsync(stream);
    }

    if (!string.IsNullOrWhiteSpace(pengguna.FotoUrl))
    {
        var previousPath = Path.Combine(webRoot, pengguna.FotoUrl.TrimStart('/').Replace('/', Path.DirectorySeparatorChar));
        if (File.Exists(previousPath)) File.Delete(previousPath);
    }

    pengguna.FotoUrl = $"/uploads/profile/{fileName}";
    await db.SaveChangesAsync();
    return Results.Ok(ToUserResponse(pengguna));
}).RequireAuthorization().DisableAntiforgery();

// ── Anggota: arus kas pribadi — rekap uang masuk/keluar dari seluruh aktivitas (simpanan, pinjaman,
// katalog) supaya anggota bisa lihat pergerakan uangnya sendiri dalam satu tempat, di halaman profil. ──
app.MapGet("/api/akun/arus-kas", async (ClaimsPrincipal principal, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    var semua = new List<ArusKasItemResponse>();

    // Simpanan: setiap mutasi lintas jenis (Pokok/Wajib/Sukarela/Berjangka) — Setor & Bunga = masuk,
    // Tarik & Pajak = keluar.
    var mutasi = await db.MutasiSimpanan.AsNoTracking()
        .Include(m => m.Simpanan).ThenInclude(s => s.JenisSimpanan)
        .Where(m => m.Simpanan.PenggunaId == pengguna.Id)
        .ToListAsync();
    foreach (var m in mutasi)
    {
        var masuk = m.Jenis is "Setor" or "Bunga";
        var label = m.Jenis switch
        {
            "Setor" => $"Setoran {m.Simpanan.JenisSimpanan.Nama}",
            "Tarik" => $"Penarikan {m.Simpanan.JenisSimpanan.Nama}",
            "Bunga" => $"Bunga {m.Simpanan.JenisSimpanan.Nama}",
            "Pajak" => $"PPh {m.Simpanan.JenisSimpanan.Nama}",
            _ => m.Simpanan.JenisSimpanan.Nama
        };
        semua.Add(new ArusKasItemResponse(m.TanggalTransaksi, "Simpanan", label, masuk ? "Masuk" : "Keluar", m.Nominal));
    }

    // Pinjaman: pencairan = masuk, angsuran/pelunasan yang sudah dibayar = keluar.
    var pinjaman = await db.Pinjaman.AsNoTracking().Where(p => p.PenggunaId == pengguna.Id).ToListAsync();
    foreach (var p in pinjaman)
    {
        semua.Add(new ArusKasItemResponse(p.TanggalMulai, "Pinjaman", $"Pencairan pinjaman {p.NomorPinjaman}", "Masuk", p.Pokok));
    }
    var angsuran = await db.AngsuranPinjaman.AsNoTracking()
        .Include(a => a.Pinjaman)
        .Where(a => a.Pinjaman.PenggunaId == pengguna.Id && a.Status == "Dibayar")
        .ToListAsync();
    foreach (var a in angsuran)
    {
        var label = a.Jenis == "Pelunasan" ? $"Pelunasan dipercepat {a.Pinjaman.NomorPinjaman}" : $"Angsuran ke-{a.AngsuranKe} {a.Pinjaman.NomorPinjaman}";
        semua.Add(new ArusKasItemResponse(a.DibayarPada ?? a.JatuhTempo, "Pinjaman", label, "Keluar", a.Total));
    }

    // Katalog: pembelian yang sudah diproses — Tunai (Selesai) dan Kredit (Disetujui, potong gaji nanti).
    var pembelian = await db.PembelianProduk.AsNoTracking().Include(x => x.Produk)
        .Where(x => x.PembeliId == pengguna.Id && (x.Status == "Selesai" || x.Status == "Disetujui"))
        .ToListAsync();
    foreach (var x in pembelian)
    {
        var label = $"{x.Jenis} {x.Produk.Nama} ({(x.MetodePembayaran == "Kredit" ? "Kredit, potong gaji" : "Tunai")})";
        semua.Add(new ArusKasItemResponse(x.DiprosesPada ?? x.DiajukanPada, "Katalog", label, "Keluar", x.Total));
    }

    var totalMasuk = semua.Where(x => x.Arah == "Masuk").Sum(x => x.Nominal);
    var totalKeluar = semua.Where(x => x.Arah == "Keluar").Sum(x => x.Nominal);
    var riwayat = semua.OrderByDescending(x => x.Tanggal).Take(50).ToList();

    return Results.Ok(new ArusKasSayaResponse(totalMasuk, totalKeluar, totalMasuk - totalKeluar, riwayat));
}).RequireAuthorization();

app.MapGet("/api/produk", async (ClaimsPrincipal principal, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();
    var produk = await db.Produk.AsNoTracking().Include(item => item.DiajukanOleh)
        .Where(item => item.Status == "Disetujui" && item.Aktif)
        .OrderByDescending(item => item.DiperbaruiPada).ThenBy(item => item.Nama)
        .ToListAsync();
    return Results.Ok(produk.Select(ToProdukResponse).ToList());
}).RequireAuthorization();

app.MapPost("/api/produk/pengajuan", async (ClaimsPrincipal principal, ProdukRequest request, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    var jenis = request.Jenis?.Trim();
    if (string.IsNullOrWhiteSpace(request.Nama) || (jenis != "Jual" && jenis != "Sewa") || request.Harga <= 0 || string.IsNullOrWhiteSpace(request.Satuan))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["produk"] = ["Nama, jenis (Jual/Sewa), harga, dan satuan wajib diisi dengan benar."]
        });
    }

    var produk = new Produk
    {
        Kode = $"PRD-{DateTime.UtcNow:yyMMddHHmmss}-{Random.Shared.Next(100, 999)}",
        Nama = request.Nama.Trim(),
        Deskripsi = string.IsNullOrWhiteSpace(request.Deskripsi) ? null : request.Deskripsi.Trim(),
        Jenis = jenis,
        Harga = request.Harga,
        Stok = request.Stok < 0 ? 0 : request.Stok,
        Satuan = request.Satuan.Trim(),
        Sumber = "TitipanAnggota",
        DiajukanOlehId = pengguna.Id,
        Status = "MenungguPersetujuan",
        Aktif = false
    };
    db.Produk.Add(produk);
    await db.SaveChangesAsync();
    return Results.Ok(ToProdukResponse(produk));
}).RequireAuthorization();

app.MapPost("/api/produk/pengajuan/{id:int}/foto", async (int id, ClaimsPrincipal principal, IFormFile file, KkcsDbContext db, IWebHostEnvironment environment) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();
    var produk = await db.Produk.FirstOrDefaultAsync(item => item.Id == id && item.DiajukanOlehId == pengguna.Id);
    if (produk is null) return Results.NotFound();

    var url = await SimpanFotoAsync(file, environment, "produk");
    if (url is null) return Results.BadRequest(new { message = "Foto harus JPG/PNG/WEBP dan maksimal 5 MB." });
    HapusFoto(produk.FotoUrl, environment);
    produk.FotoUrl = url;
    await db.SaveChangesAsync();
    return Results.Ok(ToProdukResponse(produk));
}).RequireAuthorization().DisableAntiforgery();

app.MapGet("/api/produk/pengajuan/saya", async (ClaimsPrincipal principal, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();
    var produk = await db.Produk.AsNoTracking().Include(item => item.DiajukanOleh)
        .Where(item => item.DiajukanOlehId == pengguna.Id)
        .OrderByDescending(item => item.DiperbaruiPada)
        .ToListAsync();
    return Results.Ok(produk.Select(ToProdukResponse).ToList());
}).RequireAuthorization();

app.MapPost("/api/produk/{id:int}/beli", async (int id, ClaimsPrincipal principal, BeliProdukRequest request, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    var produk = await db.Produk.FirstOrDefaultAsync(item => item.Id == id && item.Status == "Disetujui" && item.Aktif);
    if (produk is null) return Results.NotFound(new { message = "Produk tidak tersedia." });

    var metode = request.MetodePembayaran?.Trim();
    if (request.Jumlah <= 0 || (metode != "Tunai" && metode != "Kredit"))
    {
        return Results.BadRequest(new { message = "Jumlah wajib lebih dari 0 dan metode pembayaran harus Tunai atau Kredit." });
    }

    var jenisTransaksi = produk.Jenis == "Sewa" ? "Sewa" : "Beli";
    if (jenisTransaksi == "Beli" && produk.Stok < request.Jumlah)
    {
        return Results.BadRequest(new { message = $"Stok tidak mencukupi. Sisa stok {produk.Stok:0.###} {produk.Satuan}." });
    }

    var pembelian = new PembelianProduk
    {
        ProdukId = produk.Id,
        PembeliId = pengguna.Id,
        NomorTransaksi = $"TRX-{DateTime.UtcNow:yyyyMMddHHmmss}-{Random.Shared.Next(100, 999)}",
        Jenis = jenisTransaksi,
        Jumlah = request.Jumlah,
        HargaSatuan = produk.Harga,
        Total = Math.Round(produk.Harga * request.Jumlah, 2),
        MetodePembayaran = metode,
        Status = "Diajukan",
        Catatan = string.IsNullOrWhiteSpace(request.Catatan) ? null : request.Catatan.Trim()
    };
    db.PembelianProduk.Add(pembelian);
    await db.SaveChangesAsync();
    return Results.Ok(new { message = "Pengajuan pembelian terkirim. Menunggu persetujuan pengurus." });
}).RequireAuthorization();

app.MapGet("/api/produk/pembelian/saya", async (ClaimsPrincipal principal, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();
    var data = await db.PembelianProduk.AsNoTracking().Include(item => item.Produk).Include(item => item.TagihanKredit)
        .Where(item => item.PembeliId == pengguna.Id)
        .OrderByDescending(item => item.DiajukanPada)
        .ToListAsync();
    return Results.Ok(data.Select(item => new PembelianResponse(
        item.Id, item.NomorTransaksi, item.Produk.Nama, item.Jenis, item.Jumlah, item.HargaSatuan, item.Total,
        item.MetodePembayaran, item.Status, item.Catatan, item.CatatanReview, item.DiajukanPada,
        item.TagihanKredit == null ? null : new TagihanKreditRingkas(item.TagihanKredit.Id, item.TagihanKredit.Total, item.TagihanKredit.Status))).ToList());
}).RequireAuthorization();

app.MapGet("/api/admin/produk", async (KkcsDbContext db, HttpResponse response, int? halaman, int? ukuran) =>
{
    var query = db.Produk.AsNoTracking().Include(item => item.DiajukanOleh)
        .OrderByDescending(item => item.Status == "MenungguPersetujuan").ThenByDescending(item => item.DiperbaruiPada).AsQueryable();
    if (ukuran is > 0)
    {
        var total = await query.CountAsync();
        var ukuranHalaman = Math.Min(ukuran.Value, 200);
        var nomorHalaman = halaman is > 0 ? halaman.Value : 1;
        query = query.Skip((nomorHalaman - 1) * ukuranHalaman).Take(ukuranHalaman);
        response.Headers["X-Total-Count"] = total.ToString();
    }
    var produk = await query.ToListAsync();
    return Results.Ok(produk.Select(ToProdukResponse).ToList());
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/produk", async (ProdukRequest request, KkcsDbContext db) =>
{
    var jenis = request.Jenis?.Trim();
    if (string.IsNullOrWhiteSpace(request.Nama) || (jenis != "Jual" && jenis != "Sewa") || request.Harga <= 0 || string.IsNullOrWhiteSpace(request.Satuan))
    {
        return Results.BadRequest(new { message = "Nama, jenis (Jual/Sewa), harga, dan satuan wajib diisi dengan benar." });
    }
    var produk = new Produk
    {
        Kode = $"PRD-{DateTime.UtcNow:yyMMddHHmmss}-{Random.Shared.Next(100, 999)}",
        Nama = request.Nama.Trim(),
        Deskripsi = string.IsNullOrWhiteSpace(request.Deskripsi) ? null : request.Deskripsi.Trim(),
        Jenis = jenis,
        Harga = request.Harga,
        Stok = request.Stok < 0 ? 0 : request.Stok,
        Satuan = request.Satuan.Trim(),
        Sumber = "Koperasi",
        Status = "Disetujui",
        Aktif = true
    };
    db.Produk.Add(produk);
    await db.SaveChangesAsync();
    return Results.Ok(ToProdukResponse(produk));
}).RequireAuthorization("Pengurus");

app.MapPut("/api/admin/produk/{id:int}", async (int id, ProdukRequest request, KkcsDbContext db) =>
{
    var produk = await db.Produk.FirstOrDefaultAsync(item => item.Id == id);
    if (produk is null) return Results.NotFound();
    var jenis = request.Jenis?.Trim();
    if (string.IsNullOrWhiteSpace(request.Nama) || (jenis != "Jual" && jenis != "Sewa") || request.Harga <= 0 || string.IsNullOrWhiteSpace(request.Satuan))
    {
        return Results.BadRequest(new { message = "Nama, jenis (Jual/Sewa), harga, dan satuan wajib diisi dengan benar." });
    }
    produk.Nama = request.Nama.Trim();
    produk.Deskripsi = string.IsNullOrWhiteSpace(request.Deskripsi) ? null : request.Deskripsi.Trim();
    produk.Jenis = jenis;
    produk.Harga = request.Harga;
    produk.Stok = request.Stok < 0 ? 0 : request.Stok;
    produk.Satuan = request.Satuan.Trim();
    produk.DiperbaruiPada = DateTime.UtcNow;
    await db.SaveChangesAsync();
    return Results.Ok(ToProdukResponse(produk));
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/produk/{id:int}/foto", async (int id, IFormFile file, KkcsDbContext db, IWebHostEnvironment environment) =>
{
    var produk = await db.Produk.FirstOrDefaultAsync(item => item.Id == id);
    if (produk is null) return Results.NotFound();
    var url = await SimpanFotoAsync(file, environment, "produk");
    if (url is null) return Results.BadRequest(new { message = "Foto harus JPG/PNG/WEBP dan maksimal 5 MB." });
    HapusFoto(produk.FotoUrl, environment);
    produk.FotoUrl = url;
    produk.DiperbaruiPada = DateTime.UtcNow;
    await db.SaveChangesAsync();
    return Results.Ok(ToProdukResponse(produk));
}).RequireAuthorization("Pengurus").DisableAntiforgery();

app.MapPatch("/api/admin/produk/{id:int}/status", async (int id, ToggleUserStatusRequest request, ClaimsPrincipal principal, KkcsDbContext db, AuditService audit) =>
{
    var produk = await db.Produk.FirstOrDefaultAsync(item => item.Id == id);
    if (produk is null) return Results.NotFound();
    produk.Aktif = request.Aktif;
    produk.DiperbaruiPada = DateTime.UtcNow;
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Katalog", request.Aktif ? "Aktifkan" : "Nonaktifkan",
        $"{(request.Aktif ? "Mengaktifkan" : "Menonaktifkan")} produk {produk.Nama} ({produk.Kode}).", produk.Id);
    return Results.Ok(ToProdukResponse(produk));
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/produk/pengajuan/{id:int}/putusan", async (int id, PutusanProdukRequest request, ClaimsPrincipal principal, KkcsDbContext db, AuditService audit) =>
{
    var produk = await db.Produk.Include(item => item.DiajukanOleh).FirstOrDefaultAsync(item => item.Id == id);
    if (produk is null) return Results.NotFound();
    if (produk.Status != "MenungguPersetujuan") return Results.BadRequest(new { message = "Pengajuan produk ini sudah diproses." });

    produk.CatatanReview = string.IsNullOrWhiteSpace(request.Catatan) ? null : request.Catatan.Trim();
    produk.DiperbaruiPada = DateTime.UtcNow;
    if (!request.Setuju)
    {
        produk.Status = "Ditolak";
        await db.SaveChangesAsync();
        await audit.CatatAsync(principal, "Katalog", "Tolak", $"Menolak titipan produk {produk.Nama} dari {produk.DiajukanOleh?.NamaLengkap ?? "-"}.", produk.Id);
        return Results.Ok(new { message = "Pengajuan titipan produk ditolak." });
    }

    if (request.Harga is > 0) produk.Harga = request.Harga.Value;
    produk.Status = "Disetujui";
    produk.Aktif = true;
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Katalog", "Setujui", $"Menyetujui titipan produk {produk.Nama} dari {produk.DiajukanOleh?.NamaLengkap ?? "-"} (Rp {produk.Harga:N0}).", produk.Id);
    return Results.Ok(ToProdukResponse(produk));
}).RequireAuthorization("Pengurus");

app.MapGet("/api/admin/produk/pembelian", async (KkcsDbContext db) =>
    Results.Ok(await db.PembelianProduk.AsNoTracking().Include(item => item.Produk).Include(item => item.Pembeli)
        .OrderByDescending(item => item.Status == "Diajukan").ThenByDescending(item => item.DiajukanPada)
        .Select(item => new AdminPembelianResponse(
            item.Id, item.NomorTransaksi, item.Pembeli.NamaLengkap, item.Pembeli.NomorIndukKaryawan, item.Produk.Nama,
            item.Jenis, item.Jumlah, item.HargaSatuan, item.Total, item.MetodePembayaran, item.Status,
            item.Catatan, item.CatatanReview, item.DiajukanPada, item.DiprosesPada))
        .ToListAsync()))
    .RequireAuthorization("Pengurus");

app.MapPost("/api/admin/produk/pembelian/{id:int}/putusan", async (int id, PutusanPengajuanRequest request, ClaimsPrincipal principal, KkcsDbContext db, JurnalService jurnalService, AuditService audit) =>
{
    var pembelian = await db.PembelianProduk.Include(item => item.Produk).Include(item => item.TagihanKredit).Include(item => item.Pembeli)
        .FirstOrDefaultAsync(item => item.Id == id);
    if (pembelian is null) return Results.NotFound();
    if (pembelian.Status != "Diajukan") return Results.BadRequest(new { message = "Transaksi ini sudah diproses." });

    pembelian.CatatanReview = string.IsNullOrWhiteSpace(request.Catatan) ? null : request.Catatan.Trim();
    pembelian.DiprosesPada = DateTime.UtcNow;

    if (!request.Setuju)
    {
        pembelian.Status = "Ditolak";
        await db.SaveChangesAsync();
        await audit.CatatAsync(principal, "Katalog", "Tolak",
            $"Menolak transaksi {pembelian.NomorTransaksi} ({pembelian.Produk.Nama}) milik {pembelian.Pembeli.NamaLengkap}.", pembelian.Id);
        return Results.Ok(new { message = "Transaksi ditolak." });
    }

    if (pembelian.Jenis == "Beli")
    {
        if (pembelian.Produk.Stok < pembelian.Jumlah)
        {
            return Results.BadRequest(new { message = $"Stok {pembelian.Produk.Nama} tidak cukup (sisa {pembelian.Produk.Stok:0.###})." });
        }
        pembelian.Produk.Stok -= pembelian.Jumlah;
        pembelian.Produk.DiperbaruiPada = DateTime.UtcNow;
    }

    var keteranganJurnal = $"{pembelian.Jenis} {pembelian.Produk.Nama} — {pembelian.Pembeli.NamaLengkap} ({pembelian.NomorTransaksi})";
    if (pembelian.MetodePembayaran == "Kredit")
    {
        pembelian.Status = "Disetujui";
        db.TagihanKredit.Add(new TagihanKredit
        {
            PembelianProdukId = pembelian.Id,
            PenggunaId = pembelian.PembeliId,
            Total = pembelian.Total,
            Status = "Belum",
            Keterangan = $"{pembelian.Jenis} {pembelian.Produk.Nama} ({pembelian.NomorTransaksi})"
        });
        await jurnalService.PostingOtomatisAsync(DateTime.UtcNow.Date, keteranganJurnal, "Produk", $"pembelian:{pembelian.Id}",
            BarisJurnal.D(KodeAkun.PiutangKreditProduk, pembelian.Total), BarisJurnal.K(KodeAkun.PendapatanPenjualanProduk, pembelian.Total));
    }
    else
    {
        pembelian.Status = "Selesai";
        await jurnalService.PostingOtomatisAsync(DateTime.UtcNow.Date, keteranganJurnal, "Produk", $"pembelian:{pembelian.Id}",
            BarisJurnal.D(KodeAkun.Kas, pembelian.Total), BarisJurnal.K(KodeAkun.PendapatanPenjualanProduk, pembelian.Total));
    }

    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Katalog", "Setujui",
        $"Menyetujui transaksi {pembelian.NomorTransaksi} ({pembelian.Jenis} {pembelian.Produk.Nama}, {pembelian.MetodePembayaran}) milik {pembelian.Pembeli.NamaLengkap} (Rp {pembelian.Total:N0}).", pembelian.Id);
    return Results.Ok(new
    {
        message = pembelian.MetodePembayaran == "Kredit"
            ? "Transaksi disetujui. Tagihan kredit dibuat, menunggu dilunasi lewat potong gaji."
            : "Transaksi tunai disetujui dan diselesaikan."
    });
}).RequireAuthorization("Pengurus");

app.MapGet("/api/admin/produk/tagihan-kredit", async (KkcsDbContext db) =>
    Results.Ok(await db.TagihanKredit.AsNoTracking().Include(item => item.Pengguna).Include(item => item.Pembelian).ThenInclude(p => p.Produk)
        .OrderByDescending(item => item.Status == "Belum").ThenByDescending(item => item.DibuatPada)
        .Select(item => new AdminTagihanKreditResponse(
            item.Id, item.PembelianProdukId, item.PenggunaId, item.Pembelian.NomorTransaksi, item.Pengguna.NamaLengkap, item.Pengguna.NomorIndukKaryawan,
            item.Keterangan ?? item.Pembelian.Produk.Nama, item.Total, item.Status, item.DibuatPada, item.LunasPada))
        .ToListAsync()))
    .RequireAuthorization("Pengurus");

// Tandai tagihan kredit lunas setelah pengurus mengonfirmasi potongan gaji sudah dieksekusi —
// satu tagihan (tagihanKreditId), per anggota (penggunaId), atau seluruhnya (tanpa keduanya).
app.MapPost("/api/admin/produk/tagihan-kredit/lunas", async (RekapTagihanRequest? request, KkcsDbContext db, JurnalService jurnalService) =>
{
    var query = db.TagihanKredit.Include(item => item.Pembelian).Where(item => item.Status == "Belum");
    if (request?.TagihanKreditId is int tkid) query = query.Where(item => item.Id == tkid);
    else if (request?.PenggunaId is int pid) query = query.Where(item => item.PenggunaId == pid);
    var target = await query.ToListAsync();
    decimal totalDitagih = 0;
    foreach (var tagihan in target)
    {
        tagihan.Status = "Lunas";
        tagihan.LunasPada = DateTime.UtcNow;
        tagihan.Pembelian.Status = "Selesai";
        totalDitagih += tagihan.Total;
    }
    if (totalDitagih > 0)
    {
        await jurnalService.PostingOtomatisAsync(DateTime.UtcNow.Date, $"Pelunasan tagihan kredit produk via potong gaji ({target.Count} tagihan)", "Produk", "tagihanKreditLunas",
            BarisJurnal.D(KodeAkun.Kas, totalDitagih), BarisJurnal.K(KodeAkun.PiutangKreditProduk, totalDitagih));
    }
    await db.SaveChangesAsync();
    return Results.Ok(new { message = $"{target.Count} tagihan ditandai lunas.", jumlah = target.Count });
}).RequireAuthorization("Pengurus");

// ── Admin: Generator laporan potong gaji (payroll) ───────────────────────────
// Merangkum Simpanan Wajib (periode berjalan, belum dibayar) + Tagihan Kredit produk
// (belum lunas) per anggota, siap diekspor pengurus sebagai CSV.
app.MapGet("/api/admin/payroll/rekap", async (string? periode, KkcsDbContext db) =>
    Results.Ok(await BuatRekapPayroll(db, periode)))
    .RequireAuthorization("Pengurus");

app.MapGet("/api/admin/payroll/rekap/ekspor", async (string? periode, KkcsDbContext db) =>
{
    var rekap = await BuatRekapPayroll(db, periode);
    var sb = new StringBuilder();
    sb.AppendLine("NIK,Nama,Simpanan Wajib,Tagihan Kredit,Cicilan Pinjaman,Sukarela Rutin,Total Potongan");
    foreach (var baris in rekap.Baris)
    {
        sb.AppendLine(string.Join(",",
            CsvHelper.Escape(baris.Nik), CsvHelper.Escape(baris.Nama),
            baris.SimpananWajib.ToString("0"), baris.TagihanKredit.ToString("0"), baris.CicilanPinjaman.ToString("0"), baris.SukarelaRutin.ToString("0"), baris.TotalPotongan.ToString("0")));
    }
    sb.AppendLine(string.Join(",", "", CsvHelper.Escape("TOTAL"),
        rekap.TotalWajib.ToString("0"), rekap.TotalKredit.ToString("0"), rekap.TotalCicilanPinjaman.ToString("0"), rekap.TotalSukarelaRutin.ToString("0"), rekap.TotalPotongan.ToString("0")));
    return Results.File(CsvHelper.ToUtf8CsvBytes(sb.ToString()), "text/csv", $"potong-gaji-{rekap.Periode}.csv");
}).RequireAuthorization("Pengurus");

// ═══ Admin: Modul Akuntansi (dapur koperasi — tidak ada endpoint anggota di sini) ═══
app.MapGet("/api/admin/akuntansi/akun", async (KkcsDbContext db) =>
    Results.Ok(await db.AkunAkuntansi.AsNoTracking().OrderBy(item => item.Kode)
        .Select(item => new AkunResponse(item.Id, item.Kode, item.Nama, item.Tipe, item.SaldoNormal, item.Sistem, item.Aktif))
        .ToListAsync()))
    .RequireAuthorization("Pengurus");

app.MapPost("/api/admin/akuntansi/akun", async (AkunRequest request, KkcsDbContext db) =>
{
    var tipeValid = new[] { "Aset", "Liabilitas", "Ekuitas", "Pendapatan", "Beban" };
    if (string.IsNullOrWhiteSpace(request.Kode) || string.IsNullOrWhiteSpace(request.Nama)
        || !tipeValid.Contains(request.Tipe) || request.SaldoNormal is not ("Debit" or "Kredit"))
    {
        return Results.BadRequest(new { message = "Kode, nama, tipe (Aset/Liabilitas/Ekuitas/Pendapatan/Beban), dan saldo normal (Debit/Kredit) wajib diisi dengan benar." });
    }
    if (await db.AkunAkuntansi.AnyAsync(item => item.Kode == request.Kode))
    {
        return Results.Conflict(new { message = "Kode akun sudah dipakai." });
    }
    var akun = new AkunAkuntansi { Kode = request.Kode.Trim(), Nama = request.Nama.Trim(), Tipe = request.Tipe, SaldoNormal = request.SaldoNormal, Sistem = false, Aktif = true };
    db.AkunAkuntansi.Add(akun);
    await db.SaveChangesAsync();
    return Results.Ok(new AkunResponse(akun.Id, akun.Kode, akun.Nama, akun.Tipe, akun.SaldoNormal, akun.Sistem, akun.Aktif));
}).RequireAuthorization("Pengurus");

app.MapPatch("/api/admin/akuntansi/akun/{id:int}", async (int id, AkunPatchRequest request, KkcsDbContext db) =>
{
    var akun = await db.AkunAkuntansi.FirstOrDefaultAsync(item => item.Id == id);
    if (akun is null) return Results.NotFound();
    if (!string.IsNullOrWhiteSpace(request.Nama)) akun.Nama = request.Nama.Trim();
    if (request.Aktif is bool aktif)
    {
        if (akun.Sistem && !aktif) return Results.BadRequest(new { message = "Akun sistem tidak bisa dinonaktifkan karena dipakai posting otomatis." });
        akun.Aktif = aktif;
    }
    await db.SaveChangesAsync();
    return Results.Ok(new AkunResponse(akun.Id, akun.Kode, akun.Nama, akun.Tipe, akun.SaldoNormal, akun.Sistem, akun.Aktif));
}).RequireAuthorization("Pengurus");

app.MapGet("/api/admin/akuntansi/jurnal", async (DateTime? dari, DateTime? sampai, int? akunId, KkcsDbContext db) =>
{
    var query = db.JurnalEntri.AsNoTracking().Include(item => item.Baris).ThenInclude(baris => baris.Akun).Include(item => item.DicatatOleh).AsQueryable();
    if (dari is not null) query = query.Where(item => item.Tanggal >= dari.Value.Date);
    if (sampai is not null) query = query.Where(item => item.Tanggal <= sampai.Value.Date);
    if (akunId is not null) query = query.Where(item => item.Baris.Any(baris => baris.AkunId == akunId));
    var data = await query.OrderByDescending(item => item.Tanggal).ThenByDescending(item => item.Id).Take(500).ToListAsync();
    return Results.Ok(data.Select(ToJurnalResponse).ToList());
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/akuntansi/jurnal", async (JurnalManualRequest request, ClaimsPrincipal principal, KkcsDbContext db, JurnalService jurnalService, AuditService audit) =>
{
    var pengguna = await FindCurrentUser(principal, db);
    if (string.IsNullOrWhiteSpace(request.Keterangan) || request.Baris is null || request.Baris.Count < 2)
    {
        return Results.BadRequest(new { message = "Keterangan wajib diisi dan jurnal minimal 2 baris." });
    }
    try
    {
        var baris = new List<BarisJurnal>();
        foreach (var item in request.Baris)
        {
            var akun = await db.AkunAkuntansi.FindAsync(item.AkunId) ?? throw new InvalidOperationException($"Akun {item.AkunId} tidak ditemukan.");
            baris.Add(new BarisJurnal(akun.Kode, item.Debit, item.Kredit));
        }
        var entri = await jurnalService.CatatAsync(request.Tanggal, request.Keterangan.Trim(), "Manual", null, null, pengguna?.Id, baris);
        await db.SaveChangesAsync();
        var hasil = await db.JurnalEntri.AsNoTracking().Include(item => item.Baris).ThenInclude(baris => baris.Akun).Include(item => item.DicatatOleh)
            .FirstAsync(item => item.Id == entri.Id);
        await audit.CatatAsync(principal, "Akuntansi", "Buat",
            $"Membuat jurnal manual {hasil.NomorJurnal}: {hasil.Keterangan}.", hasil.Id, new { baris = request.Baris });
        return Results.Ok(ToJurnalResponse(hasil));
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(new { message = ex.Message });
    }
}).RequireAuthorization("Pengurus");

app.MapDelete("/api/admin/akuntansi/jurnal/{id:int}", async (int id, ClaimsPrincipal principal, KkcsDbContext db, AuditService audit) =>
{
    var entri = await db.JurnalEntri.FirstOrDefaultAsync(item => item.Id == id);
    if (entri is null) return Results.NotFound();
    if (entri.Sumber != "Manual") return Results.BadRequest(new { message = "Hanya jurnal manual yang bisa dihapus; jurnal otomatis mengikuti transaksi sumbernya." });
    db.JurnalEntri.Remove(entri);
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Akuntansi", "Hapus", $"Menghapus jurnal manual {entri.NomorJurnal}: {entri.Keterangan}.", entri.Id);
    return Results.Ok(new { message = "Jurnal dihapus." });
}).RequireAuthorization("Pengurus");

// Rincian ringkas 1 akun (dipakai pop-up klik kode akun di Neraca) — sengaja cuma info penting:
// saldo per tanggal terpilih + beberapa transaksi terbaru, bukan buku besar lengkap.
app.MapGet("/api/admin/akuntansi/akun/{kode}/rincian", async (string kode, DateTime? dari, DateTime? sampai, KkcsDbContext db) =>
{
    var akun = await db.AkunAkuntansi.AsNoTracking().FirstOrDefaultAsync(a => a.Kode == kode);
    if (akun is null) return Results.NotFound(new { message = $"Akun dengan kode \"{kode}\" tidak ditemukan." });

    var akhir = (sampai ?? DateTime.UtcNow).Date.AddDays(1).AddTicks(-1);
    var barisQuery = db.JurnalBaris.AsNoTracking().Include(b => b.JurnalEntri)
        .Where(b => b.AkunId == akun.Id && b.JurnalEntri.Tanggal <= akhir);
    // Untuk akun Pendapatan/Beban, "dari" membatasi ke periode Hasil Usaha yang sedang dilihat (bukan
    // saldo kumulatif sejak akun dibuat) — Aset/Liabilitas/Ekuitas di Neraca tidak mengirim "dari".
    if (dari is not null) barisQuery = barisQuery.Where(b => b.JurnalEntri.Tanggal >= dari.Value.Date);

    var totalDebit = await barisQuery.SumAsync(b => (decimal?)b.Debit) ?? 0;
    var totalKredit = await barisQuery.SumAsync(b => (decimal?)b.Kredit) ?? 0;
    var saldo = akun.SaldoNormal == "Debit" ? totalDebit - totalKredit : totalKredit - totalDebit;
    var totalTransaksi = await barisQuery.CountAsync();

    var terbaru = await barisQuery.OrderByDescending(b => b.JurnalEntri.Tanggal).ThenByDescending(b => b.JurnalEntriId)
        .Take(25)
        .Select(b => new { b.JurnalEntri.Tanggal, b.JurnalEntri.NomorJurnal, b.JurnalEntri.Keterangan, b.Debit, b.Kredit })
        .ToListAsync();

    return Results.Ok(new { akun.Kode, akun.Nama, akun.Tipe, saldo, totalTransaksi, terbaru });
}).RequireAuthorization("Pengurus");

app.MapGet("/api/admin/akuntansi/neraca", async (DateTime? tanggal, KkcsDbContext db) =>
{
    var neraca = await AkuntansiReportService.HitungNeracaAsync(db, tanggal ?? DateTime.UtcNow);
    var catatan = await db.KonfigurasiKoperasi.AsNoTracking().Select(k => k.CatatanNeraca).FirstOrDefaultAsync();
    return Results.Ok(neraca with { Catatan = catatan });
})
    .RequireAuthorization("Pengurus");

app.MapGet("/api/admin/akuntansi/laba-rugi", async (DateTime? dari, DateTime? sampai, KkcsDbContext db) =>
{
    var s = sampai ?? DateTime.UtcNow;
    var d = dari ?? new DateTime(s.Year, 1, 1);
    return Results.Ok(await AkuntansiReportService.HitungLabaRugiAsync(db, d, s));
}).RequireAuthorization("Pengurus");

app.MapGet("/api/admin/akuntansi/arus-kas", async (DateTime? dari, DateTime? sampai, KkcsDbContext db) =>
{
    var s = sampai ?? DateTime.UtcNow;
    var d = dari ?? new DateTime(s.Year, 1, 1);
    return Results.Ok(await AkuntansiReportService.HitungArusKasAsync(db, d, s));
}).RequireAuthorization("Pengurus");

// ═══ Admin: Migrasi Data — Import Neraca Awal (template Excel → jurnal umum) ═══
app.MapGet("/api/admin/migrasi/neraca-awal/template", async (KkcsDbContext db) =>
{
    var akun = await db.AkunAkuntansi.AsNoTracking().Where(a => a.Aktif).ToListAsync();
    var bytes = MigrasiService.BuatTemplateNeracaAwal(akun);
    return Results.File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "Template Neraca Awal KKCS.xlsx");
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/migrasi/neraca-awal/preview", async (IFormFile file, KkcsDbContext db, MigrasiSignatureService signatureService) =>
{
    if (file.Length == 0) return Results.BadRequest(new { message = "File kosong." });
    var akunList = await db.AkunAkuntansi.AsNoTracking().Where(a => a.Aktif).ToListAsync();
    var akunByKode = akunList.ToDictionary(a => a.Kode);

    List<NeracaAwalBarisParsed> baris;
    try
    {
        await using var stream = file.OpenReadStream();
        baris = MigrasiService.ParseNeracaAwal(stream, akunByKode);
    }
    catch (Exception ex)
    {
        return Results.BadRequest(new { message = $"Gagal membaca file Excel: {ex.Message}" });
    }

    if (baris.Count == 0) return Results.BadRequest(new { message = "Tidak ada baris berisi nominal Debit/Kredit di file ini." });

    var totalDebit = Math.Round(baris.Sum(b => b.Debit), 2, MidpointRounding.AwayFromZero);
    var totalKredit = Math.Round(baris.Sum(b => b.Kredit), 2, MidpointRounding.AwayFromZero);
    var balanced = Math.Abs(totalDebit - totalKredit) < 0.01m && baris.Count >= 2 && baris.All(b => b.Error is null);
    // Tanda tangan atas nominal yang BARU SAJA diuraikan dari file ini — dicek ulang saat komit supaya
    // nominal yang benar-benar diproses selalu sama persis dengan hasil pratinjau file, bukan angka
    // yang disusun/diubah di sisi klien.
    var signature = signatureService.Tandatangani(baris.Select(b => new NeracaAwalBarisInput(b.KodeAkun, b.Debit, b.Kredit)).ToList());
    return Results.Ok(new { baris, totalDebit, totalKredit, balanced, signature });
}).RequireAuthorization("Pengurus").DisableAntiforgery();

app.MapPost("/api/admin/migrasi/neraca-awal/komit", async (NeracaAwalKomitRequest request, ClaimsPrincipal principal, KkcsDbContext db, JurnalService jurnalService, AuditService audit, MigrasiSignatureService signatureService) =>
{
    if (request.Baris is null || request.Baris.Count(b => b.Debit != 0 || b.Kredit != 0) < 2)
        return Results.BadRequest(new { message = "Minimal 2 baris (debit dan kredit) yang berisi nominal." });
    if (!signatureService.Verifikasi(request.Baris, request.Signature))
        return Results.BadRequest(new { message = "Data tidak cocok dengan hasil pratinjau — silakan unggah & pratinjau ulang file sebelum komit." });
    if (string.IsNullOrWhiteSpace(request.Keterangan))
        return Results.BadRequest(new { message = "Keterangan wajib diisi." });

    var subject = principal.FindFirstValue(ClaimTypes.NameIdentifier);
    int? dicatatOlehId = int.TryParse(subject, out var pid) ? pid : null;
    var barisJurnal = request.Baris.Select(b => new BarisJurnal(b.KodeAkun, b.Debit, b.Kredit)).ToArray();

    try
    {
        var entri = await jurnalService.CatatAsync(request.Tanggal, request.Keterangan.Trim(), "Manual", "Migrasi", null, dicatatOlehId, barisJurnal);
        await db.SaveChangesAsync();
        await audit.CatatAsync(principal, "Migrasi", "ImportNeracaAwal",
            $"Import Neraca Awal: {request.Baris.Count} baris, tanggal {request.Tanggal:d}.", entri.Id,
            new { totalDebit = barisJurnal.Sum(b => b.Debit), totalKredit = barisJurnal.Sum(b => b.Kredit) });
        return Results.Ok(new { message = "Neraca awal berhasil diimpor sebagai jurnal umum.", jurnalId = entri.Id, nomorJurnal = entri.NomorJurnal });
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(new { message = ex.Message });
    }
}).RequireAuthorization("Pengurus");

// ═══ Admin: Migrasi Data — Import Simpanan Pokok & Wajib (per-anggota) ═══════
app.MapGet("/api/admin/migrasi/simpanan/template", async (KkcsDbContext db) =>
{
    var anggota = await db.Pengguna.AsNoTracking().Where(p => p.StatusKeanggotaan == "Aktif").ToListAsync();
    var bytes = MigrasiService.BuatTemplateSimpanan(anggota);
    return Results.File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "Template Simpanan Pokok Wajib KKCS.xlsx");
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/migrasi/simpanan/preview", async (IFormFile file, KkcsDbContext db, MigrasiSignatureService signatureService) =>
{
    if (file.Length == 0) return Results.BadRequest(new { message = "File kosong." });
    var anggotaByNik = await db.Pengguna.AsNoTracking().Where(p => p.StatusKeanggotaan == "Aktif")
        .ToDictionaryAsync(p => p.NomorIndukKaryawan);

    List<MigrasiService.SimpananBarisParsed> baris;
    try
    {
        await using var stream = file.OpenReadStream();
        baris = MigrasiService.ParseSimpanan(stream, anggotaByNik);
    }
    catch (Exception ex) { return Results.BadRequest(new { message = $"Gagal membaca file Excel: {ex.Message}" }); }

    if (baris.Count == 0) return Results.BadRequest(new { message = "Tidak ada baris berisi Saldo Pokok/Wajib di file ini." });

    var nikGanda = baris.GroupBy(b => b.Nik).Where(g => g.Count() > 1).Select(g => g.Key).ToList();
    if (nikGanda.Count > 0)
        baris = baris.Select(b => nikGanda.Contains(b.Nik) ? b with { Error = b.Error ?? "NIK muncul lebih dari sekali di file ini." } : b).ToList();

    // Anggota yang sudah punya saldo Pokok/Wajib tersimpan tidak boleh di-import ulang (cegah dobel).
    var idTerlibat = baris.Where(b => b.PenggunaId.HasValue).Select(b => b.PenggunaId!.Value).ToHashSet();
    var sudahAda = await db.Simpanan.AsNoTracking()
        .Where(s => idTerlibat.Contains(s.PenggunaId) && s.Saldo != 0 && (s.JenisSimpanan.Kode == "POKOK" || s.JenisSimpanan.Kode == "WAJIB"))
        .Select(s => s.PenggunaId).ToListAsync();
    var sudahAdaSet = sudahAda.ToHashSet();
    baris = baris.Select(b => b.PenggunaId.HasValue && sudahAdaSet.Contains(b.PenggunaId.Value)
        ? b with { Error = b.Error ?? "Anggota ini sudah punya saldo Pokok/Wajib tersimpan — tidak bisa diimpor ulang." }
        : b).ToList();

    var valid = baris.Where(b => b.Error is null).ToList();
    var signature = signatureService.Tandatangani(valid.Where(b => b.PenggunaId.HasValue)
        .Select(b => new SimpananMigrasiBarisInput(b.PenggunaId!.Value, b.SaldoPokok, b.SaldoWajib)).ToList());
    return Results.Ok(new
    {
        baris,
        totalPokok = valid.Sum(b => b.SaldoPokok),
        totalWajib = valid.Sum(b => b.SaldoWajib),
        jumlahValid = valid.Count,
        jumlahError = baris.Count - valid.Count,
        signature
    });
}).RequireAuthorization("Pengurus").DisableAntiforgery();

app.MapPost("/api/admin/migrasi/simpanan/komit", async (SimpananMigrasiKomitRequest request, ClaimsPrincipal principal, KkcsDbContext db, JurnalService jurnalService, AuditService audit, MigrasiSignatureService signatureService) =>
{
    if (request.Baris is null || request.Baris.Count == 0) return Results.BadRequest(new { message = "Tidak ada baris untuk diimpor." });
    if (!signatureService.Verifikasi(request.Baris, request.Signature))
        return Results.BadRequest(new { message = "Data tidak cocok dengan hasil pratinjau — silakan unggah & pratinjau ulang file sebelum komit." });

    var jenisPokok = await db.JenisSimpanan.FirstOrDefaultAsync(j => j.Kode == "POKOK");
    var jenisWajib = await db.JenisSimpanan.FirstOrDefaultAsync(j => j.Kode == "WAJIB");
    if (jenisPokok is null || jenisWajib is null) return Results.BadRequest(new { message = "Jenis Simpanan Pokok/Wajib belum ada di sistem." });

    var penggunaIds = request.Baris.Select(b => b.PenggunaId).ToList();
    var penggunaMap = await db.Pengguna.Where(p => penggunaIds.Contains(p.Id)).ToDictionaryAsync(p => p.Id);
    var sudahAda = await db.Simpanan.Where(s => penggunaIds.Contains(s.PenggunaId) && s.Saldo != 0
        && (s.JenisSimpananId == jenisPokok.Id || s.JenisSimpananId == jenisWajib.Id))
        .Select(s => s.PenggunaId).ToListAsync();
    if (sudahAda.Count > 0) return Results.BadRequest(new { message = $"{sudahAda.Count} anggota di daftar ini sudah punya saldo Pokok/Wajib — batal diimpor untuk mencegah dobel." });

    decimal totalPokok = 0, totalWajib = 0;
    foreach (var b in request.Baris)
    {
        if (!penggunaMap.TryGetValue(b.PenggunaId, out var pengguna)) continue;
        if (b.SaldoPokok > 0)
        {
            var s = new Simpanan { PenggunaId = pengguna.Id, JenisSimpananId = jenisPokok.Id, NomorRekening = $"{pengguna.NomorIndukKaryawan}-POKOK", Saldo = b.SaldoPokok, TanggalBuka = request.Tanggal, Aktif = true };
            db.Simpanan.Add(s);
            s.Mutasi.Add(new MutasiSimpanan { Jenis = "Setor", Nominal = b.SaldoPokok, SaldoSetelah = b.SaldoPokok, Keterangan = "Migrasi saldo awal dari sistem lama", TanggalTransaksi = request.Tanggal });
            totalPokok += b.SaldoPokok;
        }
        if (b.SaldoWajib > 0)
        {
            var s = new Simpanan { PenggunaId = pengguna.Id, JenisSimpananId = jenisWajib.Id, NomorRekening = $"{pengguna.NomorIndukKaryawan}-WAJIB", Saldo = b.SaldoWajib, TanggalBuka = request.Tanggal, Aktif = true };
            db.Simpanan.Add(s);
            s.Mutasi.Add(new MutasiSimpanan { Jenis = "Setor", Nominal = b.SaldoWajib, SaldoSetelah = b.SaldoWajib, Keterangan = "Migrasi saldo awal dari sistem lama", TanggalTransaksi = request.Tanggal });
            totalWajib += b.SaldoWajib;
        }
    }

    if (totalPokok == 0 && totalWajib == 0) return Results.BadRequest(new { message = "Tidak ada nominal yang diimpor." });

    var subject = principal.FindFirstValue(ClaimTypes.NameIdentifier);
    int? dicatatOlehId = int.TryParse(subject, out var pid) ? pid : null;
    var barisJurnal = new List<BarisJurnal> { BarisJurnal.D(KodeAkun.KliringMigrasi, totalPokok + totalWajib) };
    if (totalPokok > 0) barisJurnal.Add(BarisJurnal.K(KodeAkun.SimpananPokok, totalPokok));
    if (totalWajib > 0) barisJurnal.Add(BarisJurnal.K(KodeAkun.SimpananWajib, totalWajib));

    var entri = await jurnalService.CatatAsync(request.Tanggal, $"Migrasi Simpanan Pokok & Wajib ({request.Baris.Count} anggota)", "Manual", "Migrasi", null, dicatatOlehId, barisJurnal);
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Migrasi", "ImportSimpanan",
        $"Import Simpanan Pokok & Wajib: {request.Baris.Count} anggota, total Pokok {totalPokok:N0}, Wajib {totalWajib:N0}.", entri.Id);
    return Results.Ok(new { message = "Simpanan Pokok & Wajib berhasil diimpor.", jurnalId = entri.Id, nomorJurnal = entri.NomorJurnal, totalPokok, totalWajib });
}).RequireAuthorization("Pengurus");

// ═══ Admin: Migrasi Data — Import Pinjaman Aktif (per-anggota) ══════════════
app.MapGet("/api/admin/migrasi/pinjaman/template", async (KkcsDbContext db) =>
{
    var anggota = await db.Pengguna.AsNoTracking().Where(p => p.StatusKeanggotaan == "Aktif").ToListAsync();
    var bytes = MigrasiService.BuatTemplatePinjaman(anggota);
    return Results.File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "Template Pinjaman Aktif KKCS.xlsx");
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/migrasi/pinjaman/preview", async (IFormFile file, KkcsDbContext db, MigrasiSignatureService signatureService) =>
{
    if (file.Length == 0) return Results.BadRequest(new { message = "File kosong." });
    var anggotaByNik = await db.Pengguna.AsNoTracking().Where(p => p.StatusKeanggotaan == "Aktif")
        .ToDictionaryAsync(p => p.NomorIndukKaryawan);

    List<MigrasiService.PinjamanBarisParsed> baris;
    try
    {
        await using var stream = file.OpenReadStream();
        baris = MigrasiService.ParsePinjaman(stream, anggotaByNik);
    }
    catch (Exception ex) { return Results.BadRequest(new { message = $"Gagal membaca file Excel: {ex.Message}" }); }

    if (baris.Count == 0) return Results.BadRequest(new { message = "Tidak ada baris pinjaman di file ini." });

    var hasil = baris.Select(b =>
    {
        if (b.Error is not null || b.TanggalMulai is null) return new { b.Baris, b.Nik, b.Nama, b.PenggunaId, b.Nominal, b.TenorBulan, TanggalMulai = b.TanggalMulai, b.AngsuranSudahDibayar, sisaPokok = 0m, angsuranPerBulan = 0m, error = b.Error };
        var ringkasan = PinjamanKalkulator.Hitung(b.Nominal, b.TenorBulan);
        var pokokTerbayar = Math.Round(ringkasan.PokokPerBulan * b.AngsuranSudahDibayar, 2, MidpointRounding.AwayFromZero);
        var sisaPokok = b.SisaPokokOverride ?? (b.Nominal - pokokTerbayar);
        return new { b.Baris, b.Nik, b.Nama, b.PenggunaId, b.Nominal, b.TenorBulan, TanggalMulai = b.TanggalMulai, b.AngsuranSudahDibayar, sisaPokok, angsuranPerBulan = ringkasan.AngsuranPerBulan, error = b.Error };
    }).ToList();

    var valid = hasil.Where(h => h.error is null).ToList();
    // sisaPokokOverride tidak dipakai UI importer ini (selalu null saat komit) — samakan di tanda tangan.
    var signature = signatureService.Tandatangani(valid.Where(h => h.PenggunaId.HasValue && h.TanggalMulai.HasValue)
        .Select(h => new PinjamanMigrasiBarisInput(h.PenggunaId!.Value, h.Nominal, h.TenorBulan, h.TanggalMulai!.Value, h.AngsuranSudahDibayar, null)).ToList());
    return Results.Ok(new { baris = hasil, totalSisaPokok = valid.Sum(h => h.sisaPokok), jumlahValid = valid.Count, jumlahError = hasil.Count - valid.Count, signature });
}).RequireAuthorization("Pengurus").DisableAntiforgery();

app.MapPost("/api/admin/migrasi/pinjaman/komit", async (PinjamanMigrasiKomitRequest request, ClaimsPrincipal principal, KkcsDbContext db, JurnalService jurnalService, AuditService audit, MigrasiSignatureService signatureService) =>
{
    if (request.Baris is null || request.Baris.Count == 0) return Results.BadRequest(new { message = "Tidak ada baris untuk diimpor." });
    if (!signatureService.Verifikasi(request.Baris, request.Signature))
        return Results.BadRequest(new { message = "Data tidak cocok dengan hasil pratinjau — silakan unggah & pratinjau ulang file sebelum komit." });

    var penggunaIds = request.Baris.Select(b => b.PenggunaId).ToList();
    var penggunaMap = await db.Pengguna.Where(p => penggunaIds.Contains(p.Id)).ToDictionaryAsync(p => p.Id);

    decimal totalSisaPokok = 0;
    var urutan = 0;
    foreach (var b in request.Baris)
    {
        urutan++;
        if (!penggunaMap.TryGetValue(b.PenggunaId, out var pengguna)) continue;
        if (!PinjamanKalkulator.TenorValid.Contains(b.TenorBulan)) continue;

        var ringkasan = PinjamanKalkulator.Hitung(b.Nominal, b.TenorBulan);
        var pengajuan = new PengajuanPinjaman
        {
            PenggunaId = pengguna.Id,
            NomorPengajuan = $"PLJ-MIG-{DateTime.UtcNow:yyyyMMddHHmmss}-{urutan:D4}-{Random.Shared.Next(100, 999)}",
            Nominal = b.Nominal,
            TenorBulan = b.TenorBulan,
            BungaTahunan = ringkasan.BungaTahunan,
            EstimasiCicilanBulanan = ringkasan.AngsuranPerBulan,
            EstimasiTotalJasa = ringkasan.TotalJasa,
            Tujuan = "[Migrasi data lama]",
            Status = "Disetujui",
            DiputuskanPada = request.Tanggal
        };
        db.PengajuanPinjaman.Add(pengajuan);

        var pokokTerbayar = Math.Round(ringkasan.PokokPerBulan * b.AngsuranSudahDibayar, 2, MidpointRounding.AwayFromZero);
        var sisaPokok = b.SisaPokokOverride ?? (b.Nominal - pokokTerbayar);
        var pinjaman = new Pinjaman
        {
            PenggunaId = pengguna.Id,
            Pengajuan = pengajuan,
            NomorPinjaman = $"PJM-MIG-{DateTime.UtcNow:yyyyMMddHHmmss}-{urutan:D4}-{Random.Shared.Next(100, 999)}",
            Pokok = b.Nominal,
            TenorBulan = b.TenorBulan,
            BungaTahunan = ringkasan.BungaTahunan,
            PokokPerBulan = ringkasan.PokokPerBulan,
            JasaPerBulan = ringkasan.JasaPerBulan,
            AngsuranPerBulan = ringkasan.AngsuranPerBulan,
            SisaPokok = sisaPokok,
            AngsuranTerbayar = b.AngsuranSudahDibayar,
            TanggalMulai = b.TanggalMulai,
            Status = "Aktif"
        };
        var jadwal = PinjamanKalkulator.BuatJadwal(pinjaman);
        for (var i = 0; i < b.AngsuranSudahDibayar && i < jadwal.Count; i++)
        {
            jadwal[i].Status = "Dibayar";
            jadwal[i].JumlahDibayar = jadwal[i].Total;
            jadwal[i].DibayarPada = jadwal[i].JatuhTempo;
        }
        pinjaman.Angsuran = jadwal;
        db.Pinjaman.Add(pinjaman);
        totalSisaPokok += sisaPokok;
    }

    if (totalSisaPokok <= 0) return Results.BadRequest(new { message = "Tidak ada sisa pokok pinjaman yang diimpor." });

    var subject = principal.FindFirstValue(ClaimTypes.NameIdentifier);
    int? dicatatOlehId = int.TryParse(subject, out var pid) ? pid : null;
    var entri = await jurnalService.CatatAsync(request.Tanggal, $"Migrasi Pinjaman Aktif ({request.Baris.Count} anggota)", "Manual", "Migrasi", null, dicatatOlehId,
        [BarisJurnal.D(KodeAkun.PiutangPinjaman, totalSisaPokok), BarisJurnal.K(KodeAkun.KliringMigrasi, totalSisaPokok)]);
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Migrasi", "ImportPinjaman",
        $"Import Pinjaman Aktif: {request.Baris.Count} anggota, total sisa pokok {totalSisaPokok:N0}.", entri.Id);
    return Results.Ok(new { message = "Pinjaman aktif berhasil diimpor.", jurnalId = entri.Id, nomorJurnal = entri.NomorJurnal, totalSisaPokok });
}).RequireAuthorization("Pengurus");

// ═══ Admin: Migrasi Data — Import Tagihan Kredit (per-anggota) ══════════════
app.MapGet("/api/admin/migrasi/tagihan-kredit/template", async (KkcsDbContext db) =>
{
    var anggota = await db.Pengguna.AsNoTracking().Where(p => p.StatusKeanggotaan == "Aktif").ToListAsync();
    var bytes = MigrasiService.BuatTemplateTagihanKredit(anggota);
    return Results.File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "Template Tagihan Kredit KKCS.xlsx");
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/migrasi/tagihan-kredit/preview", async (IFormFile file, KkcsDbContext db, MigrasiSignatureService signatureService) =>
{
    if (file.Length == 0) return Results.BadRequest(new { message = "File kosong." });
    var anggotaByNik = await db.Pengguna.AsNoTracking().Where(p => p.StatusKeanggotaan == "Aktif")
        .ToDictionaryAsync(p => p.NomorIndukKaryawan);

    List<MigrasiService.TagihanKreditBarisParsed> baris;
    try
    {
        await using var stream = file.OpenReadStream();
        baris = MigrasiService.ParseTagihanKredit(stream, anggotaByNik);
    }
    catch (Exception ex) { return Results.BadRequest(new { message = $"Gagal membaca file Excel: {ex.Message}" }); }

    if (baris.Count == 0) return Results.BadRequest(new { message = "Tidak ada baris tagihan kredit di file ini." });

    var hasil = baris.Select(b =>
    {
        if (b.Error is not null) return new { b.Baris, b.Nik, b.Nama, b.PenggunaId, b.Keterangan, b.Total, b.TenorBulan, TanggalMulai = b.TanggalMulai, b.AngsuranSudahDibayar, sisaTagihan = 0m, error = b.Error };
        var angsuranPerBulan = Math.Round(b.Total / b.TenorBulan, 2, MidpointRounding.AwayFromZero);
        var terbayar = Math.Round(angsuranPerBulan * b.AngsuranSudahDibayar, 2, MidpointRounding.AwayFromZero);
        var sisaTagihan = b.SisaOverride ?? Math.Max(0, b.Total - terbayar);
        return new { b.Baris, b.Nik, b.Nama, b.PenggunaId, b.Keterangan, b.Total, b.TenorBulan, TanggalMulai = b.TanggalMulai, b.AngsuranSudahDibayar, sisaTagihan, error = b.Error };
    }).ToList();

    var valid = hasil.Where(h => h.error is null).ToList();
    var signature = signatureService.Tandatangani(valid.Where(h => h.PenggunaId.HasValue && h.TanggalMulai.HasValue)
        .Select(h => new TagihanKreditMigrasiBarisInput(h.PenggunaId!.Value, h.Keterangan, h.Total, h.TenorBulan, h.TanggalMulai!.Value, h.AngsuranSudahDibayar, null)).ToList());
    return Results.Ok(new { baris = hasil, totalSisaTagihan = valid.Sum(h => h.sisaTagihan), jumlahValid = valid.Count, jumlahError = hasil.Count - valid.Count, signature });
}).RequireAuthorization("Pengurus").DisableAntiforgery();

app.MapPost("/api/admin/migrasi/tagihan-kredit/komit", async (TagihanKreditMigrasiKomitRequest request, ClaimsPrincipal principal, KkcsDbContext db, JurnalService jurnalService, AuditService audit, MigrasiSignatureService signatureService) =>
{
    if (request.Baris is null || request.Baris.Count == 0) return Results.BadRequest(new { message = "Tidak ada baris untuk diimpor." });
    if (!signatureService.Verifikasi(request.Baris, request.Signature))
        return Results.BadRequest(new { message = "Data tidak cocok dengan hasil pratinjau — silakan unggah & pratinjau ulang file sebelum komit." });

    var penggunaIds = request.Baris.Select(b => b.PenggunaId).ToList();
    var penggunaMap = await db.Pengguna.Where(p => penggunaIds.Contains(p.Id)).ToDictionaryAsync(p => p.Id);
    var produkPlaceholder = await db.Produk.FirstOrDefaultAsync(p => p.Kode == "PRD-MIGRASI");
    if (produkPlaceholder is null) return Results.BadRequest(new { message = "Produk placeholder migrasi tidak ditemukan — hubungi pengembang." });

    decimal totalSisaTagihan = 0;
    var urutan = 0;
    foreach (var b in request.Baris)
    {
        urutan++;
        if (!penggunaMap.TryGetValue(b.PenggunaId, out var pengguna)) continue;
        if (b.TenorBulan < 1) continue;

        var pembelian = new PembelianProduk
        {
            ProdukId = produkPlaceholder.Id,
            PembeliId = pengguna.Id,
            NomorTransaksi = $"TRX-MIG-{DateTime.UtcNow:yyyyMMddHHmmss}-{urutan:D4}-{Random.Shared.Next(100, 999)}",
            Jenis = "Beli",
            Jumlah = 1,
            HargaSatuan = b.Total,
            Total = b.Total,
            MetodePembayaran = "Kredit",
            Status = "Selesai",
            Catatan = "Migrasi data lama",
            DiajukanPada = b.TanggalMulai,
            DiprosesPada = b.TanggalMulai
        };
        db.PembelianProduk.Add(pembelian);

        var angsuranPerBulan = Math.Round(b.Total / b.TenorBulan, 2, MidpointRounding.AwayFromZero);
        var terbayar = Math.Round(angsuranPerBulan * b.AngsuranSudahDibayar, 2, MidpointRounding.AwayFromZero);
        var sisaTagihan = b.SisaPokokOverride ?? Math.Max(0, b.Total - terbayar);
        var tagihan = new TagihanKredit
        {
            Pembelian = pembelian,
            PenggunaId = pengguna.Id,
            Total = b.Total,
            Status = sisaTagihan <= 0 ? "Lunas" : "Belum",
            Keterangan = b.Keterangan,
            TenorBulan = b.TenorBulan,
            AngsuranPerBulan = angsuranPerBulan,
            DibuatPada = b.TanggalMulai,
            LunasPada = sisaTagihan <= 0 ? b.TanggalMulai : null
        };

        var jadwal = new List<AngsuranTagihanKredit>(b.TenorBulan);
        decimal terjadwal = 0;
        for (var ke = 1; ke <= b.TenorBulan; ke++)
        {
            var nominal = ke == b.TenorBulan ? b.Total - terjadwal : angsuranPerBulan;
            terjadwal += nominal;
            var status = ke <= b.AngsuranSudahDibayar ? "Dibayar" : "Belum";
            jadwal.Add(new AngsuranTagihanKredit
            {
                AngsuranKe = ke,
                JatuhTempo = b.TanggalMulai.AddMonths(ke),
                Nominal = nominal,
                Status = status,
                JumlahDibayar = status == "Dibayar" ? nominal : null,
                DibayarPada = status == "Dibayar" ? b.TanggalMulai.AddMonths(ke) : null
            });
        }
        tagihan.Angsuran = jadwal;
        db.TagihanKredit.Add(tagihan);
        totalSisaTagihan += sisaTagihan;
    }

    if (totalSisaTagihan <= 0) return Results.BadRequest(new { message = "Tidak ada sisa tagihan kredit yang diimpor (semua sudah lunas atau tidak ada baris valid)." });

    var subject = principal.FindFirstValue(ClaimTypes.NameIdentifier);
    int? dicatatOlehId = int.TryParse(subject, out var pid) ? pid : null;
    var entri = await jurnalService.CatatAsync(request.Tanggal, $"Migrasi Tagihan Kredit ({request.Baris.Count} anggota)", "Manual", "Migrasi", null, dicatatOlehId,
        [BarisJurnal.D(KodeAkun.PiutangKreditProduk, totalSisaTagihan), BarisJurnal.K(KodeAkun.KliringMigrasi, totalSisaTagihan)]);
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Migrasi", "ImportTagihanKredit",
        $"Import Tagihan Kredit: {request.Baris.Count} anggota, total sisa tagihan {totalSisaTagihan:N0}.", entri.Id);
    return Results.Ok(new { message = "Tagihan kredit berhasil diimpor.", jurnalId = entri.Id, nomorJurnal = entri.NomorJurnal, totalSisaTagihan });
}).RequireAuthorization("Pengurus");

// ═══ Admin: Migrasi Data — Import Jurnal Harian (banyak transaksi, tanggal beda-beda) ═══
app.MapGet("/api/admin/migrasi/jurnal-harian/template", async (KkcsDbContext db) =>
{
    var akun = await db.AkunAkuntansi.AsNoTracking().Where(a => a.Aktif).ToListAsync();
    var bytes = MigrasiService.BuatTemplateJurnalHarian(akun);
    return Results.File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "Template Jurnal Harian KKCS.xlsx");
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/migrasi/jurnal-harian/preview", async (IFormFile file, KkcsDbContext db, MigrasiSignatureService signatureService) =>
{
    if (file.Length == 0) return Results.BadRequest(new { message = "File kosong." });
    var akunList = await db.AkunAkuntansi.AsNoTracking().Where(a => a.Aktif).ToListAsync();
    var akunByKode = akunList.ToDictionary(a => a.Kode);
    var anggotaByNik = await db.Pengguna.AsNoTracking().Where(p => p.StatusKeanggotaan == "Aktif")
        .ToDictionaryAsync(p => p.NomorIndukKaryawan);

    List<MigrasiService.JurnalHarianBarisParsed> baris;
    try
    {
        await using var stream = file.OpenReadStream();
        baris = MigrasiService.ParseJurnalHarian(stream, akunByKode, anggotaByNik);
    }
    catch (Exception ex) { return Results.BadRequest(new { message = $"Gagal membaca file Excel: {ex.Message}" }); }

    if (baris.Count == 0) return Results.BadRequest(new { message = "Tidak ada baris transaksi di file ini." });

    var voucher = baris.GroupBy(b => b.NoBukti).Select(g =>
    {
        var totalDebit = Math.Round(g.Sum(b => b.Debit), 2, MidpointRounding.AwayFromZero);
        var totalKredit = Math.Round(g.Sum(b => b.Kredit), 2, MidpointRounding.AwayFromZero);
        var adaError = g.Any(b => b.Error is not null);
        var balanced = !adaError && Math.Abs(totalDebit - totalKredit) < 0.01m && g.Count() >= 2;
        return new
        {
            noBukti = g.Key,
            tanggal = g.Select(b => b.Tanggal).FirstOrDefault(t => t is not null),
            keterangan = g.Select(b => b.Keterangan).FirstOrDefault(k => !string.IsNullOrWhiteSpace(k)),
            baris = g.Select(b => new { b.Baris, b.KodeAkun, b.NamaAkun, b.Debit, b.Kredit, b.Nik, b.PenggunaId, b.EfekSaldo, b.Error }).ToList(),
            totalDebit,
            totalKredit,
            balanced
        };
    }).OrderBy(v => v.tanggal).ToList();

    var jumlahValid = voucher.Count(v => v.balanced);
    var signature = signatureService.Tandatangani(voucher.Where(v => v.balanced && v.tanggal.HasValue)
        .Select(v => new JurnalHarianVoucherInput(v.noBukti, v.tanggal!.Value, v.keterangan ?? v.noBukti,
            v.baris.Select(b => new JurnalHarianBarisInput(b.KodeAkun, b.Debit, b.Kredit, b.PenggunaId, b.EfekSaldo)).ToList())).ToList());
    return Results.Ok(new { voucher, jumlahValid, jumlahError = voucher.Count - jumlahValid, totalVoucher = voucher.Count, signature });
}).RequireAuthorization("Pengurus").DisableAntiforgery();

app.MapPost("/api/admin/migrasi/jurnal-harian/komit", async (JurnalHarianKomitRequest request, ClaimsPrincipal principal, KkcsDbContext db, JurnalService jurnalService, AuditService audit, MigrasiSignatureService signatureService) =>
{
    if (request.Voucher is null || request.Voucher.Count == 0) return Results.BadRequest(new { message = "Tidak ada voucher untuk diimpor." });
    if (!signatureService.Verifikasi(request.Voucher, request.Signature))
        return Results.BadRequest(new { message = "Data tidak cocok dengan hasil pratinjau — silakan unggah & pratinjau ulang file sebelum komit." });

    var subject = principal.FindFirstValue(ClaimTypes.NameIdentifier);
    int? dicatatOlehId = int.TryParse(subject, out var pid) ? pid : null;
    var jenisSimpananByKode = await db.JenisSimpanan.ToDictionaryAsync(j => j.Kode);

    var berhasil = 0;
    var efekTerapkan = 0;
    try
    {
        foreach (var v in request.Voucher)
        {
            var barisJurnal = v.Baris.Select(b => new BarisJurnal(b.KodeAkun, b.Debit, b.Kredit)).ToArray();
            await jurnalService.CatatAsync(v.Tanggal, v.Keterangan, "Manual", "Migrasi", v.NoBukti, dicatatOlehId, barisJurnal);
            berhasil++;

            foreach (var b in v.Baris)
            {
                if (b.PenggunaId is null || string.IsNullOrWhiteSpace(b.EfekSaldo)) continue;
                var nominal = b.Debit > 0 ? b.Debit : b.Kredit;
                if (nominal <= 0) continue;

                switch (b.EfekSaldo)
                {
                    case "SetorPokok":
                        await MigrasiService.TerapkanSetorAsync(db, jenisSimpananByKode, "POKOK", b.PenggunaId.Value, nominal, v.Tanggal, v.Keterangan);
                        break;
                    case "SetorWajib":
                        await MigrasiService.TerapkanSetorAsync(db, jenisSimpananByKode, "WAJIB", b.PenggunaId.Value, nominal, v.Tanggal, v.Keterangan);
                        break;
                    case "SetorSukarela":
                        await MigrasiService.TerapkanSetorAsync(db, jenisSimpananByKode, "SUKARELA", b.PenggunaId.Value, nominal, v.Tanggal, v.Keterangan);
                        break;
                    case "TarikWajib":
                        await MigrasiService.TerapkanTarikAsync(db, jenisSimpananByKode, "WAJIB", b.PenggunaId.Value, nominal, v.Tanggal, v.Keterangan);
                        break;
                    case "TarikSukarela":
                        await MigrasiService.TerapkanTarikAsync(db, jenisSimpananByKode, "SUKARELA", b.PenggunaId.Value, nominal, v.Tanggal, v.Keterangan);
                        break;
                    case "AngsuranPinjaman":
                        await MigrasiService.TerapkanAngsuranAsync(db, b.PenggunaId.Value, nominal, v.Tanggal);
                        break;
                }
                efekTerapkan++;
            }
        }
        await db.SaveChangesAsync();
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(new { message = $"Gagal pada voucher ke-{berhasil + 1}: {ex.Message}" });
    }

    await audit.CatatAsync(principal, "Migrasi", "ImportJurnalHarian",
        $"Import Jurnal Harian: {request.Voucher.Count} voucher/transaksi, {efekTerapkan} efek saldo anggota diterapkan.", null,
        new { jumlahVoucher = request.Voucher.Count, jumlahEfek = efekTerapkan });
    return Results.Ok(new { message = $"{request.Voucher.Count} voucher transaksi berhasil diimpor ({efekTerapkan} baris menggerakkan saldo anggota).", jumlahVoucher = request.Voucher.Count, jumlahEfek = efekTerapkan });
}).RequireAuthorization("Pengurus");

// ═══ Admin: Kalkulator SHU (Sisa Hasil Usaha) ═══════════════════════════════
app.MapGet("/api/admin/shu/riwayat", async (KkcsDbContext db) =>
    Results.Ok(await db.ShuRun.AsNoTracking().OrderByDescending(item => item.Tahun)
        .Select(item => new ShuRiwayatResponse(
            item.Tahun, item.TotalShu, item.TotalPajak, item.TotalShuNeto,
            item.PersenAnggota, item.PersenJasaModal, item.PersenJasaUsaha, item.PersenPengurus, item.PersenCadangan,
            item.JasaPengurusPool, item.CadanganAmount, item.Rincian.Count, item.DifinalisasiPada))
        .ToListAsync()))
    .RequireAuthorization("Pengurus");

app.MapPost("/api/admin/shu/hitung", async (ShuHitungRequest request, KkcsDbContext db) =>
{
    if (request.TotalShu < 0 || request.PersenAnggota < 0 || request.PersenJasaModal < 0 || request.PersenJasaUsaha < 0 || request.PersenPengurus < 0 || request.PersenCadangan < 0 || request.Tahun < 2000)
    {
        return Results.BadRequest(new { message = "Tahun, Total SHU, dan kelima persentase wajib diisi dengan benar (tidak boleh negatif)." });
    }
    var konfigurasi = await db.KonfigurasiKoperasi.FirstAsync();
    return Results.Ok(await ShuService.HitungAsync(db, request.Tahun, request.TotalShu, request.PersenAnggota, request.PersenJasaModal, request.PersenJasaUsaha, request.PersenPengurus, request.PersenCadangan, konfigurasi.TarifPphShu));
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/shu/finalisasi", async (ShuHitungRequest request, ClaimsPrincipal principal, KkcsDbContext db, JurnalService jurnalService, AuditService audit) =>
{
    if (request.TotalShu <= 0 || request.PersenAnggota < 0 || request.PersenJasaModal < 0 || request.PersenJasaUsaha < 0 || request.PersenPengurus < 0 || request.PersenCadangan < 0 || request.Tahun < 2000)
    {
        return Results.BadRequest(new { message = "Tahun, Total SHU (harus > 0), dan kelima persentase wajib diisi dengan benar." });
    }
    var pengguna = await FindCurrentUser(principal, db);
    var konfigurasi = await db.KonfigurasiKoperasi.FirstAsync();
    var hasil = await ShuService.HitungAsync(db, request.Tahun, request.TotalShu, request.PersenAnggota, request.PersenJasaModal, request.PersenJasaUsaha, request.PersenPengurus, request.PersenCadangan, konfigurasi.TarifPphShu);

    var existing = await db.ShuRun.Include(item => item.Rincian).FirstOrDefaultAsync(item => item.Tahun == request.Tahun);
    if (existing is not null) db.ShuRun.Remove(existing);

    var run = new ShuRun
    {
        Tahun = request.Tahun,
        TotalShu = request.TotalShu,
        TotalPajak = hasil.TotalPajak,
        TotalShuNeto = hasil.TotalShuNeto,
        PersenAnggota = request.PersenAnggota,
        PersenJasaModal = request.PersenJasaModal,
        PersenJasaUsaha = request.PersenJasaUsaha,
        PersenPengurus = request.PersenPengurus,
        PersenCadangan = request.PersenCadangan,
        JasaPengurusPool = hasil.JasaPengurusPool,
        CadanganAmount = hasil.CadanganAmount,
        TotalSimpananSemuaAnggota = hasil.TotalSimpananSemuaAnggota,
        TotalTransaksiSemuaAnggota = hasil.TotalTransaksiSemuaAnggota,
        DifinalisasiOlehId = pengguna?.Id
    };
    run.Rincian = hasil.Rincian.Select(r => new ShuAnggota
    {
        PenggunaId = r.PenggunaId,
        SimpananAnggota = r.SimpananAnggota,
        TransaksiAnggota = r.TransaksiAnggota,
        JasaPinjamanAnggota = r.JasaPinjaman,
        BelanjaAnggota = r.Belanja,
        Jma = r.Jma,
        Jua = r.Jua,
        TotalShu = r.TotalShu,
        Pajak = r.Pajak,
        TotalShuNeto = r.TotalShuNeto
    }).ToList();
    db.ShuRun.Add(run);

    // Jurnal harus balance terhadap yang benar-benar teralokasi (Σ bruto anggota, bukan pot "Total SHU"
    // mentah — keduanya bisa beda kalau basis simpanan/transaksi sebagian anggota nol). Empat tujuan dana:
    //   - Cadangan Koperasi (permanen, tidak pernah dibagikan)
    //   - Utang Jasa Pengurus (lump-sum, dibagikan pengurus sendiri di luar sistem)
    //   - Utang SHU ke Anggota (neto, JMA+JUA setelah PPh)
    //   - Utang PPh (dipotong dari bagian anggota saja)
    var totalBrutoAnggota = hasil.TotalShuNeto + hasil.TotalPajak;
    var totalDialokasikan = totalBrutoAnggota + hasil.JasaPengurusPool + hasil.CadanganAmount;
    // Tidak ada apa pun untuk dijurnal kalau tidak ada dasar alokasi sama sekali (mis. Total SHU 0 atau
    // keempat persentase 0) — lewati posting daripada memaksa jurnal 0 yang tidak valid.
    if (totalDialokasikan > 0)
    {
        var baris = new List<BarisJurnal> { BarisJurnal.D(KodeAkun.ShuDitahan, totalDialokasikan) };
        if (hasil.CadanganAmount > 0) baris.Add(BarisJurnal.K(KodeAkun.CadanganKoperasi, hasil.CadanganAmount));
        if (hasil.JasaPengurusPool > 0) baris.Add(BarisJurnal.K(KodeAkun.UtangJasaPengurus, hasil.JasaPengurusPool));
        if (hasil.TotalShuNeto > 0) baris.Add(BarisJurnal.K(KodeAkun.UtangShuAnggota, hasil.TotalShuNeto));
        if (hasil.TotalPajak > 0) baris.Add(BarisJurnal.K(KodeAkun.UtangPph, hasil.TotalPajak));
        await jurnalService.PostingOtomatisAsync(new DateTime(request.Tahun, 12, 31),
            $"Apropriasi SHU tahun buku {request.Tahun}: Cadangan {request.PersenCadangan:P0}, Jasa Pengurus {request.PersenPengurus:P0}, Anggota (JMA+JUA neto setelah PPh)",
            "SHU", $"shu:{request.Tahun}", baris.ToArray());
    }

    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "SHU", "Finalisasi",
        $"Memfinalisasi SHU tahun buku {request.Tahun} sebesar Rp {request.TotalShu:N0} — Cadangan Rp {hasil.CadanganAmount:N0}, Pengurus Rp {hasil.JasaPengurusPool:N0}, Anggota neto Rp {hasil.TotalShuNeto:N0} (setelah PPh Rp {hasil.TotalPajak:N0}) untuk {hasil.Rincian.Count} anggota.", run.Id,
        new { request.Tahun, request.TotalShu, hasil.TotalPajak, hasil.TotalShuNeto, hasil.JasaPengurusPool, hasil.CadanganAmount, request.PersenAnggota, request.PersenJasaModal, request.PersenJasaUsaha, request.PersenPengurus, request.PersenCadangan, konfigurasi.TarifPph });
    return Results.Ok(new { message = $"SHU tahun {request.Tahun} difinalisasi: Cadangan Rp {hasil.CadanganAmount:N0}, Jasa Pengurus Rp {hasil.JasaPengurusPool:N0}, {hasil.Rincian.Count} anggota (neto setelah PPh) kini tampil di aplikasi anggota." });
}).RequireAuthorization("Pengurus");

app.MapGet("/api/admin/shu/{tahun:int}", async (int tahun, KkcsDbContext db) =>
{
    var run = await db.ShuRun.AsNoTracking().Include(item => item.Rincian).ThenInclude(r => r.Pengguna).FirstOrDefaultAsync(item => item.Tahun == tahun);
    if (run is null) return Results.NotFound();
    return Results.Ok(new
    {
        run.Tahun,
        run.TotalShu,
        run.TotalPajak,
        run.TotalShuNeto,
        run.PersenAnggota,
        run.PersenJasaModal,
        run.PersenJasaUsaha,
        run.PersenPengurus,
        run.PersenCadangan,
        run.JasaPengurusPool,
        run.CadanganAmount,
        run.TotalSimpananSemuaAnggota,
        run.TotalTransaksiSemuaAnggota,
        run.DifinalisasiPada,
        Rincian = run.Rincian.OrderByDescending(r => r.TotalShu).Select(r => new ShuBarisHasil(
            r.PenggunaId, r.Pengguna.NamaLengkap, r.Pengguna.NomorIndukKaryawan, r.SimpananAnggota, r.TransaksiAnggota, r.Jma, r.Jua, r.TotalShu, r.Pajak, r.TotalShuNeto, r.JasaPinjamanAnggota, r.BelanjaAnggota))
    });
}).RequireAuthorization("Pengurus");

app.MapGet("/api/admin/shu/{tahun:int}/ekspor", async (int tahun, KkcsDbContext db) =>
{
    var run = await db.ShuRun.AsNoTracking().Include(item => item.Rincian).ThenInclude(r => r.Pengguna).FirstOrDefaultAsync(item => item.Tahun == tahun);
    if (run is null) return Results.NotFound();
    var sb = new StringBuilder();
    sb.AppendLine("NIK,Nama,Simpanan Anggota,Transaksi Anggota,JMA,JUA,Total SHU (Bruto),PPh,Total SHU (Neto)");
    foreach (var r in run.Rincian.OrderByDescending(r => r.TotalShu))
    {
        sb.AppendLine(string.Join(",",
            CsvHelper.Escape(r.Pengguna.NomorIndukKaryawan), CsvHelper.Escape(r.Pengguna.NamaLengkap),
            r.SimpananAnggota.ToString("0"), r.TransaksiAnggota.ToString("0"), r.Jma.ToString("0"), r.Jua.ToString("0"),
            r.TotalShu.ToString("0"), r.Pajak.ToString("0"), r.TotalShuNeto.ToString("0")));
    }
    sb.AppendLine(string.Join(",", "", CsvHelper.Escape("TOTAL"), "", "", "", "",
        run.Rincian.Sum(r => r.TotalShu).ToString("0"), run.Rincian.Sum(r => r.Pajak).ToString("0"), run.Rincian.Sum(r => r.TotalShuNeto).ToString("0")));
    return Results.File(CsvHelper.ToUtf8CsvBytes(sb.ToString()), "text/csv", $"shu-{tahun}.csv");
}).RequireAuthorization("Pengurus");

app.MapGet("/api/simpanan/jenis", async (KkcsDbContext db) =>
    Results.Ok(await db.JenisSimpanan.AsNoTracking().Where(jenis => jenis.Aktif).OrderBy(jenis => jenis.Id).ToListAsync()))
    .RequireAuthorization();

app.MapGet("/api/beranda/ringkasan", async (ClaimsPrincipal principal, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    var rekening = await db.Simpanan.AsNoTracking().Include(item => item.JenisSimpanan)
        .Where(item => item.PenggunaId == pengguna.Id)
        .ToListAsync();
    decimal Saldo(string kode) => rekening.FirstOrDefault(item => item.JenisSimpanan.Kode == kode)?.Saldo ?? 0;

    var berjangkaAktif = (await db.SimpananBerjangka.AsNoTracking()
        .Where(item => item.PenggunaId == pengguna.Id && (item.Status == "Aktif" || item.Status == "JatuhTempo"))
        .Select(item => (decimal?)item.Nominal)
        .SumAsync()) ?? 0;

    var pinjamanAktif = await db.Pinjaman.AsNoTracking().Include(item => item.Angsuran)
        .Where(item => item.PenggunaId == pengguna.Id && item.Status == "Aktif")
        .ToListAsync();

    // ── Pengumuman (diambil dari sistem E-RAT & katalog) ──
    var pengumuman = new List<PengumumanResponse>();

    var agendaAktif = await db.EratAgenda.AsNoTracking().Include(item => item.Opsi)
        .Where(item => item.Status == "Aktif")
        .OrderByDescending(item => item.MulaiPada ?? item.DibuatPada)
        .ToListAsync();
    var sudahVote = await db.EratSuara.AsNoTracking()
        .Where(s => s.PenggunaId == pengguna.Id)
        .Select(s => s.EratAgendaId)
        .ToListAsync();
    foreach (var agenda in agendaAktif.Take(3))
    {
        pengumuman.Add(sudahVote.Contains(agenda.Id)
            ? new PengumumanResponse("vote", $"Voting E-RAT: {agenda.Judul}", "Suara Anda sudah tercatat. Lihat perolehan suara sementara.", "erat")
            : new PengumumanResponse("vote", $"Voting E-RAT dibuka: {agenda.Judul}", "Berikan hak suara Anda sekarang.", "erat"));
    }

    var laporanTerbaru = await db.LaporanTahunan.AsNoTracking()
        .Where(item => item.Aktif)
        .OrderByDescending(item => item.Tahun).ThenByDescending(item => item.DiterbitkanPada)
        .FirstOrDefaultAsync();
    if (laporanTerbaru is not null)
    {
        pengumuman.Add(new PengumumanResponse("dokumen", $"Dokumen RAT {laporanTerbaru.Tahun} tersedia", laporanTerbaru.Judul, "erat"));
    }

    // Pengumuman hanya seputar Voting E-RAT & dokumen RAT.
    if (pengumuman.Count == 0)
    {
        pengumuman.Add(new PengumumanResponse("info", "Belum ada pengumuman E-RAT", "Agenda voting dan dokumen RAT akan tampil di sini.", ""));
    }

    var produkTerbaru = await db.Produk.AsNoTracking().Include(item => item.DiajukanOleh)
        .Where(item => item.Status == "Disetujui" && item.Aktif)
        .OrderByDescending(item => item.DiperbaruiPada).ThenBy(item => item.Nama)
        .Take(5)
        .ToListAsync();

    // Estimasi SHU: ambil dari tahun buku SHU terfinalisasi paling baru yang memuat anggota ini.
    var estimasiShu = await db.ShuAnggota.AsNoTracking().Include(item => item.ShuRun)
        .Where(item => item.PenggunaId == pengguna.Id)
        .OrderByDescending(item => item.ShuRun.Tahun)
        .Select(item => new { item.ShuRun.Tahun, TotalShu = item.TotalShuNeto }) // ditampilkan neto — setelah PPh — sesuai yang benar-benar diterima anggota.
        .FirstOrDefaultAsync();

    return Results.Ok(new BerandaRingkasanResponse(
        Saldo("POKOK") + Saldo("WAJIB") + Saldo("SUKARELA") + berjangkaAktif,
        Saldo("POKOK"),
        Saldo("WAJIB"),
        Saldo("SUKARELA"),
        berjangkaAktif,
        pinjamanAktif.Count,
        pinjamanAktif.Sum(item => item.SisaPokok),
        pinjamanAktif.Sum(item => item.AngsuranPerBulan),
        pinjamanAktif.Sum(item => item.Angsuran.Count(a => a.Status == "Belum" && a.Jenis == "Reguler")),
        pengumuman,
        produkTerbaru.Select(ToProdukResponse).ToList(),
        estimasiShu == null ? null : new EstimasiShuResponse(estimasiShu.Tahun, estimasiShu.TotalShu)));
}).RequireAuthorization();

app.MapGet("/api/simpanan/saya", async (ClaimsPrincipal principal, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    var konfigurasi = await db.KonfigurasiKoperasi.AsNoTracking().FirstAsync();
    var rekening = await db.Simpanan.AsNoTracking().Include(item => item.JenisSimpanan).Include(item => item.Mutasi)
        .Where(item => item.PenggunaId == pengguna.Id)
        .ToListAsync();
    Simpanan? RekeningJenis(string kode) => rekening.FirstOrDefault(item => item.JenisSimpanan.Kode == kode);

    var tagihan = await db.TagihanWajib.AsNoTracking()
        .Where(item => item.PenggunaId == pengguna.Id)
        .OrderByDescending(item => item.Periode)
        .Select(item => new TagihanWajibResponse(item.Id, item.Periode, item.Nominal, item.JatuhTempo, item.Status, item.CatatanReview, item.DiprosesPada))
        .ToListAsync();

    var sukarela = await db.TransaksiSukarela.AsNoTracking()
        .Where(item => item.PenggunaId == pengguna.Id)
        .OrderByDescending(item => item.DiajukanPada)
        .Select(item => new TransaksiSukarelaResponse(item.Id, item.Jenis, item.Nominal, item.Catatan, item.Status, item.CatatanReview, item.DiajukanPada, item.DiprosesPada, item.BuktiTransferUrl))
        .ToListAsync();

    var produkBerjangka = await db.ProdukBerjangka.AsNoTracking()
        .Where(item => item.Aktif)
        .OrderBy(item => item.Nominal)
        .Select(item => new ProdukBerjangkaResponse(item.Id, item.Nama, item.Nominal, item.TenorBulan, item.Aktif))
        .ToListAsync();

    var berjangkaSaya = await db.SimpananBerjangka.AsNoTracking().Include(item => item.Produk)
        .Where(item => item.PenggunaId == pengguna.Id)
        .OrderByDescending(item => item.DiajukanPada)
        .ToListAsync();

    decimal Saldo(string kode) => RekeningJenis(kode)?.Saldo ?? 0;
    string? NoRek(string kode) => RekeningJenis(kode)?.NomorRekening;

    var mutasi = rekening
        .SelectMany(item => item.Mutasi.Select(m => new { item.JenisSimpanan.Nama, m.Id, Data = new MutasiResponse(item.JenisSimpanan.Nama, m.Jenis, m.Nominal, m.SaldoSetelah, m.Keterangan, m.TanggalTransaksi) }))
        .OrderByDescending(item => item.Data.Tanggal).ThenByDescending(item => item.Id)
        .Take(20)
        .Select(item => item.Data)
        .ToList();

    return Results.Ok(new SimpananSayaResponse(
        pengguna.StatusKeanggotaan,
        new SimpananRekeningResponse(Saldo("POKOK"), NoRek("POKOK")),
        new SimpananWajibResponse(Saldo("WAJIB"), NoRek("WAJIB"), konfigurasi.SimpananWajibNominal, konfigurasi.TanggalTagihWajib, tagihan),
        new SimpananSukarelaResponse(Saldo("SUKARELA"), NoRek("SUKARELA"), konfigurasi.BungaSukarelaTahunan, konfigurasi.TarifPph, sukarela),
        new SimpananBerjangkaBagianResponse(konfigurasi.BungaDepositoTahunan, produkBerjangka,
            berjangkaSaya.Select(item => ToBerjangkaResponse(item, konfigurasi.BungaDepositoTahunan)).ToList()),
        mutasi));
}).RequireAuthorization();

// ── Anggota: riwayat SHU pribadi (rincian JMA/JUA/PPh per tahun buku yang sudah difinalisasi) ──
app.MapGet("/api/shu/saya", async (ClaimsPrincipal principal, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    var riwayat = await db.ShuAnggota.AsNoTracking().Include(item => item.ShuRun)
        .Where(item => item.PenggunaId == pengguna.Id)
        .OrderByDescending(item => item.ShuRun.Tahun)
        .Select(item => new ShuSayaResponse(
            item.ShuRun.Tahun, item.SimpananAnggota, item.TransaksiAnggota,
            item.Jma, item.Jua, item.TotalShu, item.Pajak, item.TotalShuNeto,
            item.ShuRun.PersenAnggota, item.ShuRun.PersenJasaModal, item.ShuRun.PersenJasaUsaha, item.ShuRun.DifinalisasiPada))
        .ToListAsync();

    return Results.Ok(riwayat);
}).RequireAuthorization();

app.MapPost("/api/simpanan/sukarela", async (ClaimsPrincipal principal, [FromForm] string jenis, [FromForm] decimal nominal, [FromForm] string? catatan, IFormFile? bukti, KkcsDbContext db, SimpananService simpananService, IWebHostEnvironment environment) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    jenis = jenis?.Trim() ?? "";
    if (jenis != "Setor" && jenis != "Tarik")
    {
        return Results.BadRequest(new { message = "Jenis transaksi harus 'Setor' atau 'Tarik'." });
    }
    if (nominal <= 0)
    {
        return Results.ValidationProblem(new Dictionary<string, string[]> { ["nominal"] = ["Nominal wajib lebih dari 0."] });
    }
    if (await db.TransaksiSukarela.AnyAsync(item => item.PenggunaId == pengguna.Id && item.Status == "Diajukan"))
    {
        return Results.Conflict(new { message = "Masih ada pengajuan simpanan sukarela yang menunggu persetujuan." });
    }
    if (jenis == "Tarik")
    {
        var saldo = await simpananService.SaldoAsync(pengguna.Id, "SUKARELA");
        if (nominal > saldo)
        {
            return Results.BadRequest(new { message = $"Saldo sukarela tidak cukup. Saldo saat ini {saldo:N0}." });
        }
    }

    string? buktiUrl = null;
    if (jenis == "Setor")
    {
        if (bukti is null) return Results.BadRequest(new { message = "Bukti transfer wajib diunggah untuk setoran sukarela." });
        buktiUrl = await SimpanBuktiAsync(bukti, environment, "bukti-sukarela");
        if (buktiUrl is null) return Results.BadRequest(new { message = "File bukti transfer tidak valid — pakai JPG/PNG/PDF, maksimal 10MB." });
    }

    db.TransaksiSukarela.Add(new TransaksiSukarela
    {
        PenggunaId = pengguna.Id,
        Jenis = jenis,
        Nominal = nominal,
        Catatan = string.IsNullOrWhiteSpace(catatan) ? null : catatan.Trim(),
        BuktiTransferUrl = buktiUrl
    });
    await db.SaveChangesAsync();
    return Results.Ok(new { message = "Pengajuan simpanan sukarela terkirim. Menunggu persetujuan pengurus." });
}).RequireAuthorization().DisableAntiforgery();

app.MapGet("/api/simpanan/sukarela-rutin/saya", async (ClaimsPrincipal principal, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    var rutin = await db.SukarelaRutin.AsNoTracking()
        .Where(item => item.PenggunaId == pengguna.Id && item.Status != "Ditolak" && item.Status != "Dihentikan")
        .OrderByDescending(item => item.DiajukanPada)
        .FirstOrDefaultAsync();
    return Results.Ok(rutin is null ? null : ToSukarelaRutinResponse(rutin));
}).RequireAuthorization();

app.MapPost("/api/simpanan/sukarela-rutin", async (ClaimsPrincipal principal, SukarelaRutinRequest request, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();
    if (request.Nominal <= 0 || request.TanggalSetor is < 1 or > 28)
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["sukarelaRutin"] = ["Nominal wajib lebih dari 0 dan tanggal setor antara 1-28."]
        });
    }
    if (await db.SukarelaRutin.AnyAsync(item => item.PenggunaId == pengguna.Id && item.Status != "Ditolak" && item.Status != "Dihentikan"))
    {
        return Results.Conflict(new { message = "Anda sudah punya instruksi Sukarela Rutin yang aktif/menunggu persetujuan." });
    }

    var rutin = new SukarelaRutin { PenggunaId = pengguna.Id, Nominal = request.Nominal, TanggalSetor = request.TanggalSetor };
    db.SukarelaRutin.Add(rutin);
    await db.SaveChangesAsync();
    return Results.Ok(new { message = "Pengajuan Sukarela Rutin terkirim. Menunggu persetujuan pengurus." });
}).RequireAuthorization();

app.MapPost("/api/simpanan/sukarela-rutin/{id:int}/berhenti", async (int id, ClaimsPrincipal principal, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    var rutin = await db.SukarelaRutin.FirstOrDefaultAsync(item => item.Id == id && item.PenggunaId == pengguna.Id);
    if (rutin is null) return Results.NotFound();
    if (rutin.Status != "Aktif") return Results.BadRequest(new { message = "Hanya instruksi yang sedang Aktif yang bisa diajukan berhenti." });

    rutin.Status = "DihentikanDiajukan";
    await db.SaveChangesAsync();
    return Results.Ok(new { message = "Pengajuan berhenti Sukarela Rutin terkirim. Menunggu persetujuan pengurus." });
}).RequireAuthorization();

app.MapPost("/api/simpanan/berjangka", async (ClaimsPrincipal principal, [FromForm] int produkBerjangkaId, IFormFile? bukti, KkcsDbContext db, IWebHostEnvironment environment) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    var produk = await db.ProdukBerjangka.FirstOrDefaultAsync(item => item.Id == produkBerjangkaId && item.Aktif);
    if (produk is null) return Results.BadRequest(new { message = "Produk simpanan berjangka tidak tersedia." });

    if (bukti is null) return Results.BadRequest(new { message = "Bukti transfer wajib diunggah untuk pengajuan simpanan berjangka." });
    var buktiUrl = await SimpanBuktiAsync(bukti, environment, "bukti-berjangka");
    if (buktiUrl is null) return Results.BadRequest(new { message = "File bukti transfer tidak valid — pakai JPG/PNG/PDF, maksimal 10MB." });

    db.SimpananBerjangka.Add(new SimpananBerjangka
    {
        PenggunaId = pengguna.Id,
        ProdukBerjangkaId = produk.Id,
        NomorSertifikat = $"BJK-{DateTime.UtcNow:yyyyMMddHHmmss}-{Random.Shared.Next(100, 999)}",
        Nominal = produk.Nominal,
        TenorBulan = produk.TenorBulan,
        Status = "Diajukan",
        BuktiTransferUrl = buktiUrl
    });
    await db.SaveChangesAsync();
    return Results.Ok(new { message = "Pengajuan simpanan berjangka terkirim. Menunggu persetujuan pengurus." });
}).RequireAuthorization().DisableAntiforgery();

app.MapPost("/api/simpanan/berjangka/{id:int}/pencairan", async (int id, ClaimsPrincipal principal, AjukanPencairanRequest? request, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    var berjangka = await db.SimpananBerjangka.FirstOrDefaultAsync(item => item.Id == id && item.PenggunaId == pengguna.Id);
    if (berjangka is null) return Results.NotFound();
    if (berjangka.Status != "Aktif")
    {
        return Results.BadRequest(new { message = "Hanya simpanan berjangka aktif yang bisa diajukan pencairan dipercepat." });
    }
    if (berjangka.PencairanDiajukan)
    {
        return Results.Conflict(new { message = "Pengajuan pencairan dipercepat sudah dikirim dan menunggu persetujuan pengurus." });
    }

    berjangka.PencairanDiajukan = true;
    berjangka.PencairanDiajukanPada = DateTime.UtcNow;
    berjangka.AlasanPencairan = string.IsNullOrWhiteSpace(request?.Alasan) ? null : request.Alasan.Trim();
    await db.SaveChangesAsync();
    return Results.Ok(new { message = "Pengajuan pencairan dipercepat terkirim. Bunga tidak dibayarkan bila disetujui." });
}).RequireAuthorization();

app.MapGet("/api/pinjaman/tarif", () => Results.Ok(PinjamanKalkulator.TenorValid
    .Select(tenor =>
    {
        var ringkasan = PinjamanKalkulator.Hitung(1_000_000m, tenor);
        return new TarifPinjamanResponse(tenor, ringkasan.BungaTahunan);
    })))
    .RequireAuthorization();

app.MapPost("/api/pinjaman/simulasi", (PengajuanPinjamanRequest request) =>
{
    if (request.Nominal <= 0 || !PinjamanKalkulator.TenorValid.Contains(request.TenorBulan))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["pinjaman"] = ["Nominal wajib lebih dari 0 dan tenor harus 12, 24, 36, 48, atau 60 bulan."]
        });
    }

    var ringkasan = PinjamanKalkulator.Hitung(request.Nominal, request.TenorBulan);
    return Results.Ok(new SimulasiPinjamanResponse(
        request.Nominal,
        request.TenorBulan,
        ringkasan.BungaTahunan,
        ringkasan.PokokPerBulan,
        ringkasan.JasaPerBulan,
        ringkasan.AngsuranPerBulan,
        ringkasan.TotalJasa,
        request.Nominal + ringkasan.TotalJasa));
}).RequireAuthorization();

app.MapPost("/api/pinjaman", async (ClaimsPrincipal principal, PengajuanPinjamanRequest request, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();
    if (request.Nominal <= 0 || string.IsNullOrWhiteSpace(request.Tujuan) || !PinjamanKalkulator.TenorValid.Contains(request.TenorBulan))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["pinjaman"] = ["Nominal dan tujuan wajib diisi, dan tenor harus 12, 24, 36, 48, atau 60 bulan."]
        });
    }

    var ringkasan = PinjamanKalkulator.Hitung(request.Nominal, request.TenorBulan);
    var pengajuan = new PengajuanPinjaman
    {
        PenggunaId = pengguna.Id,
        NomorPengajuan = $"PLJ-{DateTime.UtcNow:yyyyMMddHHmmss}-{Random.Shared.Next(100, 999)}",
        Nominal = request.Nominal,
        TenorBulan = request.TenorBulan,
        BungaTahunan = ringkasan.BungaTahunan,
        EstimasiCicilanBulanan = ringkasan.AngsuranPerBulan,
        EstimasiTotalJasa = ringkasan.TotalJasa,
        Tujuan = request.Tujuan.Trim(),
        Status = "Draft"
    };
    db.PengajuanPinjaman.Add(pengajuan);
    await db.SaveChangesAsync();
    return Results.Created($"/api/pinjaman/{pengajuan.Id}", ToPengajuanResponse(pengajuan));
}).RequireAuthorization();

app.MapGet("/api/pinjaman/{id:int}/draft/pdf", async (int id, ClaimsPrincipal principal, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    var pengajuan = await db.PengajuanPinjaman.FirstOrDefaultAsync(item => item.Id == id && item.PenggunaId == pengguna.Id);
    if (pengajuan is null) return Results.NotFound();
    if (pengajuan.Status != "Draft" && pengajuan.Status != "Diajukan")
        return Results.BadRequest(new { message = "Draft ini sudah diputuskan pengurus, cetak tidak lagi relevan." });

    var pdf = DraftPinjamanPdf.Buat(pengguna, pengajuan);
    return Results.File(pdf, "application/pdf", $"Draft-Pengajuan-Pinjaman-{pengajuan.NomorPengajuan}.pdf");
}).RequireAuthorization();

app.MapPost("/api/pinjaman/{id:int}/rekomendasi", async (int id, ClaimsPrincipal principal, IFormFile? file, KkcsDbContext db, IWebHostEnvironment environment) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    var pengajuan = await db.PengajuanPinjaman.FirstOrDefaultAsync(item => item.Id == id && item.PenggunaId == pengguna.Id);
    if (pengajuan is null) return Results.NotFound();
    if (pengajuan.Status != "Draft") return Results.BadRequest(new { message = "Pengajuan ini sudah diajukan atau diputuskan, tidak bisa diunggah ulang." });
    if (file is null) return Results.BadRequest(new { message = "Surat rekomendasi wajib diunggah." });

    var url = await SimpanBuktiAsync(file, environment, "rekomendasi-pinjaman");
    if (url is null) return Results.BadRequest(new { message = "File tidak valid — pakai JPG/PNG/PDF, maksimal 10MB." });

    pengajuan.SuratRekomendasiUrl = url;
    pengajuan.Status = "Diajukan";
    await db.SaveChangesAsync();
    return Results.Ok(new { message = "Surat rekomendasi terunggah. Pengajuan pinjaman terkirim ke pengurus.", pengajuan = ToPengajuanResponse(pengajuan) });
}).RequireAuthorization().DisableAntiforgery();

app.MapGet("/api/pinjaman/saya", async (ClaimsPrincipal principal, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    var pengajuan = await db.PengajuanPinjaman.AsNoTracking()
        .Where(item => item.PenggunaId == pengguna.Id)
        .OrderByDescending(item => item.DibuatPada)
        .ToListAsync();

    var pinjaman = await db.Pinjaman.AsNoTracking()
        .Include(item => item.Angsuran)
        .Where(item => item.PenggunaId == pengguna.Id)
        .OrderByDescending(item => item.DibuatPada)
        .ToListAsync();

    var pembayaranTertunda = await db.PembayaranPinjaman.AsNoTracking()
        .Where(item => item.PenggunaId == pengguna.Id && item.Status == "Diajukan")
        .ToListAsync();
    var tertundaLookup = pembayaranTertunda.ToDictionary(item => item.PinjamanId);

    return Results.Ok(new PinjamanSayaResponse(
        pengajuan.Select(ToPengajuanResponse).ToList(),
        pinjaman.Select(item => ToPinjamanResponse(item, tertundaLookup.GetValueOrDefault(item.Id))).ToList()));
}).RequireAuthorization();

app.MapPost("/api/pinjaman/{id:int}/pembayaran", async (int id, [FromForm] string jenis, [FromForm] string? catatan, IFormFile? bukti, ClaimsPrincipal principal, KkcsDbContext db, IWebHostEnvironment environment) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    var pinjaman = await db.Pinjaman.Include(item => item.Angsuran)
        .FirstOrDefaultAsync(item => item.Id == id && item.PenggunaId == pengguna.Id);
    if (pinjaman is null) return Results.NotFound();
    if (pinjaman.Status != "Aktif") return Results.BadRequest(new { message = "Pinjaman ini sudah lunas." });

    jenis = jenis?.Trim() ?? "";
    if (jenis != "Angsuran" && jenis != "Pelunasan")
    {
        return Results.BadRequest(new { message = "Jenis pembayaran harus 'Angsuran' atau 'Pelunasan'." });
    }

    string? buktiUrl = null;
    if (jenis == "Pelunasan")
    {
        if (bukti is null) return Results.BadRequest(new { message = "Bukti transfer wajib diunggah untuk pelunasan dipercepat." });
        buktiUrl = await SimpanBuktiAsync(bukti, environment, "bukti-pelunasan");
        if (buktiUrl is null) return Results.BadRequest(new { message = "File bukti transfer tidak valid — pakai JPG/PNG/PDF, maksimal 10MB." });
    }

    if (await db.PembayaranPinjaman.AnyAsync(item => item.PinjamanId == id && item.Status == "Diajukan"))
    {
        return Results.Conflict(new { message = "Masih ada pengajuan pembayaran yang menunggu persetujuan pengurus." });
    }

    var sisaReguler = pinjaman.Angsuran
        .Where(item => item.Status == "Belum" && item.Jenis == "Reguler")
        .OrderBy(item => item.AngsuranKe)
        .ToList();

    PembayaranPinjaman pembayaran;
    if (jenis == "Angsuran")
    {
        var berikutnya = sisaReguler.FirstOrDefault();
        if (berikutnya is null) return Results.BadRequest(new { message = "Semua angsuran sudah terbayar." });
        pembayaran = new PembayaranPinjaman
        {
            PinjamanId = id,
            PenggunaId = pengguna.Id,
            Jenis = "Angsuran",
            JumlahDiajukan = berikutnya.Total,
            AngsuranKe = berikutnya.AngsuranKe,
            Catatan = string.IsNullOrWhiteSpace(catatan) ? null : catatan.Trim()
        };
    }
    else
    {
        pembayaran = new PembayaranPinjaman
        {
            PinjamanId = id,
            PenggunaId = pengguna.Id,
            Jenis = "Pelunasan",
            JumlahDiajukan = pinjaman.SisaPokok,
            JasaDibebaskan = sisaReguler.Sum(item => item.Jasa),
            Catatan = string.IsNullOrWhiteSpace(catatan) ? null : catatan.Trim()
        };
    }
    pembayaran.BuktiTransferUrl = buktiUrl;

    db.PembayaranPinjaman.Add(pembayaran);
    await db.SaveChangesAsync();
    return Results.Ok(new { message = "Pengajuan pembayaran terkirim. Menunggu persetujuan pengurus." });
}).RequireAuthorization().DisableAntiforgery();

app.MapGet("/api/admin/pinjaman/pengajuan", async (KkcsDbContext db) =>
    // Draft (belum ada rekomendasi SDM) sengaja tidak ditampilkan — belum resmi diajukan ke pengurus.
    Results.Ok(await db.PengajuanPinjaman.AsNoTracking().Include(item => item.Pengguna)
        .Where(item => item.Status != "Draft")
        .OrderByDescending(item => item.Status == "Diajukan").ThenByDescending(item => item.DibuatPada)
        .Select(item => new AdminPengajuanResponse(
            item.Id, item.NomorPengajuan, item.Pengguna.NamaLengkap, item.Pengguna.NomorIndukKaryawan,
            item.Nominal, item.TenorBulan, item.BungaTahunan, item.EstimasiCicilanBulanan, item.EstimasiTotalJasa,
            item.Tujuan, item.Status, item.CatatanReview, item.DibuatPada, item.DiputuskanPada, item.SuratRekomendasiUrl))
        .ToListAsync()))
    .RequireAuthorization("Pengurus");

app.MapPost("/api/admin/pinjaman/pengajuan/{id:int}/putusan", async (int id, PutusanPengajuanRequest request, ClaimsPrincipal principal, KkcsDbContext db, JurnalService jurnalService, AuditService audit) =>
{
    var pengajuan = await db.PengajuanPinjaman.Include(item => item.Pinjaman).Include(item => item.Pengguna).FirstOrDefaultAsync(item => item.Id == id);
    if (pengajuan is null) return Results.NotFound();
    if (pengajuan.Status != "Diajukan") return Results.BadRequest(new { message = "Pengajuan ini sudah diputuskan." });

    pengajuan.CatatanReview = string.IsNullOrWhiteSpace(request.Catatan) ? null : request.Catatan.Trim();
    pengajuan.DiputuskanPada = DateTime.UtcNow;

    if (!request.Setuju)
    {
        pengajuan.Status = "Ditolak";
        await db.SaveChangesAsync();
        await audit.CatatAsync(principal, "Pinjaman", "Tolak",
            $"Menolak pengajuan pinjaman {pengajuan.NomorPengajuan} milik {pengajuan.Pengguna.NamaLengkap} (Rp {pengajuan.Nominal:N0}).", pengajuan.Id,
            new { catatan = pengajuan.CatatanReview });
        return Results.Ok(new { message = "Pengajuan ditolak." });
    }

    pengajuan.Status = "Disetujui";
    var ringkasan = PinjamanKalkulator.Hitung(pengajuan.Nominal, pengajuan.TenorBulan);
    var pinjaman = new Pinjaman
    {
        PenggunaId = pengajuan.PenggunaId,
        PengajuanPinjamanId = pengajuan.Id,
        NomorPinjaman = $"PJM-{DateTime.UtcNow:yyyyMMddHHmmss}-{Random.Shared.Next(100, 999)}",
        Pokok = pengajuan.Nominal,
        TenorBulan = pengajuan.TenorBulan,
        BungaTahunan = ringkasan.BungaTahunan,
        PokokPerBulan = ringkasan.PokokPerBulan,
        JasaPerBulan = ringkasan.JasaPerBulan,
        AngsuranPerBulan = ringkasan.AngsuranPerBulan,
        SisaPokok = pengajuan.Nominal,
        AngsuranTerbayar = 0,
        TanggalMulai = (request.TanggalMulai ?? DateTime.UtcNow).Date,
        Status = "Aktif"
    };
    pinjaman.Angsuran = PinjamanKalkulator.BuatJadwal(pinjaman);
    db.Pinjaman.Add(pinjaman);

    await jurnalService.PostingOtomatisAsync(pinjaman.TanggalMulai, $"Pencairan pinjaman {pinjaman.NomorPinjaman} — {pengajuan.Pengguna.NamaLengkap}", "Pinjaman", $"pinjaman:{pengajuan.Id}",
        BarisJurnal.D(KodeAkun.PiutangPinjaman, pinjaman.Pokok), BarisJurnal.K(KodeAkun.Kas, pinjaman.Pokok));

    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Pinjaman", "Setujui",
        $"Menyetujui & mencairkan pinjaman {pinjaman.NomorPinjaman} milik {pengajuan.Pengguna.NamaLengkap} (Rp {pinjaman.Pokok:N0}, {pinjaman.TenorBulan} bulan).", pinjaman.Id,
        new { nomorPengajuan = pengajuan.NomorPengajuan, nominal = pinjaman.Pokok, tenorBulan = pinjaman.TenorBulan });
    return Results.Ok(ToPinjamanResponse(pinjaman));
}).RequireAuthorization("Pengurus");

app.MapGet("/api/admin/pinjaman", async (KkcsDbContext db, HttpResponse response, string? cari, string? status, int? halaman, int? ukuran) =>
{
    var countAktif = await db.Pinjaman.AsNoTracking().CountAsync(item => item.Status == "Aktif");
    var countLunas = await db.Pinjaman.AsNoTracking().CountAsync(item => item.Status == "Lunas");
    var totalSisaPokok = await db.Pinjaman.AsNoTracking().Where(item => item.Status == "Aktif").SumAsync(item => (decimal?)item.SisaPokok) ?? 0;
    response.Headers["X-Count-Aktif"] = countAktif.ToString();
    response.Headers["X-Count-Lunas"] = countLunas.ToString();
    response.Headers["X-Total-SisaPokok"] = totalSisaPokok.ToString(System.Globalization.CultureInfo.InvariantCulture);

    var query = db.Pinjaman.AsNoTracking().Include(item => item.Pengguna).Include(item => item.Angsuran).AsQueryable();
    if (!string.IsNullOrWhiteSpace(cari))
    {
        var needle = cari.Trim();
        query = query.Where(item => item.NomorPinjaman.Contains(needle) || item.Pengguna.NamaLengkap.Contains(needle) || item.Pengguna.NomorIndukKaryawan.Contains(needle));
    }
    if (!string.IsNullOrWhiteSpace(status)) query = query.Where(item => item.Status == status);
    query = query.OrderByDescending(item => item.Status == "Aktif").ThenByDescending(item => item.DibuatPada);

    if (ukuran is > 0)
    {
        var total = await query.CountAsync();
        var ukuranHalaman = Math.Min(ukuran.Value, 200);
        var nomorHalaman = halaman is > 0 ? halaman.Value : 1;
        query = query.Skip((nomorHalaman - 1) * ukuranHalaman).Take(ukuranHalaman);
        response.Headers["X-Total-Count"] = total.ToString();
    }
    var pinjaman = await query.ToListAsync();
    return Results.Ok(pinjaman.Select(item => ToAdminPinjamanResponse(item)).ToList());
}).RequireAuthorization("Pengurus");

app.MapGet("/api/admin/pinjaman/pembayaran", async (KkcsDbContext db) =>
    Results.Ok(await db.PembayaranPinjaman.AsNoTracking()
        .Include(item => item.Pengguna)
        .Include(item => item.Pinjaman)
        .OrderByDescending(item => item.Status == "Diajukan").ThenByDescending(item => item.DiajukanPada)
        .Select(item => new AdminPembayaranResponse(
            item.Id, item.PinjamanId, item.Pinjaman.NomorPinjaman,
            item.Pengguna.NamaLengkap, item.Pengguna.NomorIndukKaryawan,
            item.Jenis, item.JumlahDiajukan, item.JasaDibebaskan, item.AngsuranKe,
            item.Catatan, item.Status, item.CatatanReview, item.DiajukanPada, item.DiputuskanPada, item.BuktiTransferUrl))
        .ToListAsync()))
    .RequireAuthorization("Pengurus");

app.MapPost("/api/admin/pinjaman/pembayaran/{id:int}/putusan", async (int id, PutusanPembayaranRequest request, ClaimsPrincipal principal, KkcsDbContext db, JurnalService jurnalService, AuditService audit) =>
{
    var pembayaran = await db.PembayaranPinjaman
        .Include(item => item.Pinjaman).ThenInclude(pinjaman => pinjaman.Angsuran)
        .Include(item => item.Pinjaman).ThenInclude(pinjaman => pinjaman.Pengguna)
        .FirstOrDefaultAsync(item => item.Id == id);
    if (pembayaran is null) return Results.NotFound();
    if (pembayaran.Status != "Diajukan") return Results.BadRequest(new { message = "Pengajuan pembayaran ini sudah diputuskan." });

    pembayaran.CatatanReview = string.IsNullOrWhiteSpace(request.Catatan) ? null : request.Catatan.Trim();
    pembayaran.DiputuskanPada = DateTime.UtcNow;

    if (!request.Setuju)
    {
        pembayaran.Status = "Ditolak";
        await db.SaveChangesAsync();
        await audit.CatatAsync(principal, "Pinjaman", "Tolak",
            $"Menolak pengajuan pembayaran ({pembayaran.Jenis}) pinjaman {pembayaran.Pinjaman.NomorPinjaman} milik {pembayaran.Pinjaman.Pengguna.NamaLengkap}.", pembayaran.Id);
        return Results.Ok(new { message = "Pengajuan pembayaran ditolak." });
    }

    var pinjaman = pembayaran.Pinjaman;
    if (pinjaman.Status != "Aktif") return Results.BadRequest(new { message = "Pinjaman ini sudah lunas." });

    var tanggal = DateTime.UtcNow.Date;
    if (pembayaran.Jenis == "Angsuran")
    {
        var angsuran = pinjaman.Angsuran
            .Where(item => item.Status == "Belum" && item.Jenis == "Reguler")
            .OrderBy(item => item.AngsuranKe)
            .FirstOrDefault();
        if (angsuran is null) return Results.BadRequest(new { message = "Semua angsuran sudah terbayar." });

        angsuran.Status = "Dibayar";
        angsuran.DibayarPada = tanggal;
        angsuran.JumlahDibayar = angsuran.Total;
        pinjaman.SisaPokok = Math.Max(0, pinjaman.SisaPokok - angsuran.Pokok);
        pinjaman.AngsuranTerbayar += 1;
        pembayaran.AngsuranKe = angsuran.AngsuranKe;

        if (pinjaman.Angsuran.All(item => item.Status != "Belum"))
        {
            pinjaman.Status = "Lunas";
            pinjaman.LunasPada = tanggal;
            pinjaman.SisaPokok = 0;
        }

        await jurnalService.PostingOtomatisAsync(tanggal, $"Angsuran ke-{angsuran.AngsuranKe} pinjaman {pinjaman.NomorPinjaman} — {pinjaman.Pengguna.NamaLengkap}", "Pinjaman", $"pembayaran:{pembayaran.Id}",
            BarisJurnal.D(KodeAkun.Kas, angsuran.Total),
            BarisJurnal.K(KodeAkun.PiutangPinjaman, angsuran.Pokok),
            BarisJurnal.K(KodeAkun.PendapatanJasaPinjaman, angsuran.Jasa));
    }
    else
    {
        var sisaPokok = pinjaman.SisaPokok;
        foreach (var angsuran in pinjaman.Angsuran.Where(item => item.Status == "Belum"))
        {
            angsuran.Status = "Dibatalkan";
        }

        var nomorTerakhir = pinjaman.Angsuran.Count == 0 ? 0 : pinjaman.Angsuran.Max(item => item.AngsuranKe);
        pinjaman.Angsuran.Add(new AngsuranPinjaman
        {
            AngsuranKe = nomorTerakhir + 1,
            JatuhTempo = tanggal,
            Pokok = sisaPokok,
            Jasa = 0,
            Total = sisaPokok,
            Jenis = "Pelunasan",
            Status = "Dibayar",
            JumlahDibayar = sisaPokok,
            DibayarPada = tanggal
        });

        pinjaman.SisaPokok = 0;
        pinjaman.Status = "Lunas";
        pinjaman.LunasPada = tanggal;

        if (sisaPokok > 0)
        {
            await jurnalService.PostingOtomatisAsync(tanggal, $"Pelunasan dipercepat pinjaman {pinjaman.NomorPinjaman} — {pinjaman.Pengguna.NamaLengkap} (tanpa jasa)", "Pinjaman", $"pembayaran:{pembayaran.Id}",
                BarisJurnal.D(KodeAkun.Kas, sisaPokok), BarisJurnal.K(KodeAkun.PiutangPinjaman, sisaPokok));
        }
    }

    pembayaran.Status = "Disetujui";
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Pinjaman", "Setujui",
        $"Menyetujui pembayaran ({pembayaran.Jenis}) pinjaman {pinjaman.NomorPinjaman} milik {pinjaman.Pengguna.NamaLengkap}" +
        (pembayaran.Jenis == "Angsuran" ? $", angsuran ke-{pembayaran.AngsuranKe}." : ", pelunasan dipercepat."), pembayaran.Id);
    return Results.Ok(ToAdminPinjamanResponse(pinjaman));
}).RequireAuthorization("Pengurus");

// Tandai satu cicilan pinjaman (angsuran reguler) lunas langsung dari tinjauan Payroll — potongan gaji
// dieksekusi otomatis tiap bulan, jadi tidak perlu anggota mengajukan pembayaran dulu seperti pembayaran mandiri.
app.MapPost("/api/admin/pinjaman/angsuran/{id:int}/bayar", async (int id, ClaimsPrincipal principal, KkcsDbContext db, JurnalService jurnalService, AuditService audit) =>
{
    var angsuran = await db.AngsuranPinjaman.Include(item => item.Pinjaman).ThenInclude(p => p.Pengguna)
        .FirstOrDefaultAsync(item => item.Id == id);
    if (angsuran is null) return Results.NotFound();
    if (angsuran.Status != "Belum" || angsuran.Jenis != "Reguler") return Results.BadRequest(new { message = "Cicilan ini sudah diproses atau bukan angsuran reguler." });

    var pinjaman = angsuran.Pinjaman;
    if (pinjaman.Status != "Aktif") return Results.BadRequest(new { message = "Pinjaman ini sudah lunas." });

    var tanggal = DateTime.UtcNow.Date;
    angsuran.Status = "Dibayar";
    angsuran.DibayarPada = tanggal;
    angsuran.JumlahDibayar = angsuran.Total;
    pinjaman.SisaPokok = Math.Max(0, pinjaman.SisaPokok - angsuran.Pokok);
    pinjaman.AngsuranTerbayar += 1;

    if (pinjaman.Angsuran.All(item => item.Status != "Belum"))
    {
        pinjaman.Status = "Lunas";
        pinjaman.LunasPada = tanggal;
        pinjaman.SisaPokok = 0;
    }

    await jurnalService.PostingOtomatisAsync(tanggal, $"Angsuran ke-{angsuran.AngsuranKe} pinjaman {pinjaman.NomorPinjaman} via potong gaji — {pinjaman.Pengguna.NamaLengkap}", "Pinjaman", $"angsuran:{angsuran.Id}",
        BarisJurnal.D(KodeAkun.Kas, angsuran.Total),
        BarisJurnal.K(KodeAkun.PiutangPinjaman, angsuran.Pokok),
        BarisJurnal.K(KodeAkun.PendapatanJasaPinjaman, angsuran.Jasa));

    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Payroll", "TandaiLunas",
        $"Menandai cicilan ke-{angsuran.AngsuranKe} pinjaman {pinjaman.NomorPinjaman} milik {pinjaman.Pengguna.NamaLengkap} lunas via potong gaji (Rp {angsuran.Total:N0}).", angsuran.Id);
    return Results.Ok(new { message = $"Cicilan ke-{angsuran.AngsuranKe} ditandai lunas." });
}).RequireAuthorization("Pengurus");

// ── Admin: Konfigurasi koperasi ──────────────────────────────────────────────
app.MapGet("/api/admin/konfigurasi", async (KkcsDbContext db) =>
{
    var konfigurasi = await db.KonfigurasiKoperasi.AsNoTracking().FirstAsync();
    return Results.Ok(ToKonfigurasiResponse(konfigurasi));
}).RequireAuthorization("Pengurus"); // dibaca Pengurus juga (perlu tampil di panel simpanan), diubah cuma Admin (lihat PUT di bawah).

app.MapPut("/api/admin/konfigurasi", async (KonfigurasiRequest request, ClaimsPrincipal principal, KkcsDbContext db, AuditService audit) =>
{
    if (request.SimpananPokokNominal < 0 || request.SimpananWajibNominal < 0)
    {
        return Results.BadRequest(new { message = "Nominal tidak boleh negatif." });
    }
    if (request.BungaSukarelaTahunan is < 0 or > 1 || request.BungaDepositoTahunan is < 0 or > 1 || request.TarifPph is < 0 or > 1 || request.TarifPphShu is < 0 or > 1)
    {
        return Results.BadRequest(new { message = "Suku bunga & tarif pajak harus berupa fraksi 0–1 (mis. 0.025 untuk 2,5%)." });
    }
    var konfigurasi = await db.KonfigurasiKoperasi.FirstAsync();
    var sebelum = new { konfigurasi.SimpananPokokNominal, konfigurasi.SimpananWajibNominal, konfigurasi.BungaSukarelaTahunan, konfigurasi.BungaDepositoTahunan, konfigurasi.TarifPph, konfigurasi.TarifPphShu };
    konfigurasi.SimpananPokokNominal = request.SimpananPokokNominal;
    konfigurasi.SimpananWajibNominal = request.SimpananWajibNominal;
    konfigurasi.BungaSukarelaTahunan = request.BungaSukarelaTahunan;
    konfigurasi.BungaDepositoTahunan = request.BungaDepositoTahunan;
    konfigurasi.TarifPph = request.TarifPph;
    konfigurasi.TarifPphShu = request.TarifPphShu;
    konfigurasi.DiperbaruiPada = DateTime.UtcNow;
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Konfigurasi", "Ubah", "Mengubah konfigurasi koperasi (nominal simpanan/suku bunga/PPh).", konfigurasi.Id,
        new { sebelum, sesudah = new { konfigurasi.SimpananPokokNominal, konfigurasi.SimpananWajibNominal, konfigurasi.BungaSukarelaTahunan, konfigurasi.BungaDepositoTahunan, konfigurasi.TarifPph, konfigurasi.TarifPphShu } });
    return Results.Ok(ToKonfigurasiResponse(konfigurasi));
}).RequireAuthorization("Admin");

app.MapPost("/api/admin/simpanan/sukarela/bunga", async (HitungBungaRequest? request, KkcsDbContext db, SimpananService simpananService, JurnalService jurnalService) =>
{
    var konfigurasi = await db.KonfigurasiKoperasi.FirstAsync();
    var periode = string.IsNullOrWhiteSpace(request?.Periode) ? BungaSukarela.PeriodeBulanLalu() : request.Periode.Trim();
    var (akun, bruto, pajak, neto) = await BungaSukarela.PostingAsync(db, simpananService, jurnalService, konfigurasi.BungaSukarelaTahunan, konfigurasi.TarifPph, periode);
    return Results.Ok(new
    {
        message = $"Bunga sukarela periode {periode}: {akun} rekening, bruto {bruto:N0} - PPh {pajak:N0} = neto {neto:N0} dikreditkan.",
        periode,
        akun,
        bungaBruto = bruto,
        pajak,
        bungaNeto = neto
    });
}).RequireAuthorization("Pengurus");

// ── Admin: Persetujuan pendaftaran anggota (Simpanan Pokok) ───────────────────
app.MapGet("/api/admin/anggota/pendaftaran", async (KkcsDbContext db) =>
    Results.Ok(await db.Pengguna.AsNoTracking()
        .Where(item => item.StatusKeanggotaan != "Aktif")
        .OrderByDescending(item => item.StatusKeanggotaan == "MenungguPersetujuan").ThenByDescending(item => item.DibuatPada)
        .Select(item => new PendaftaranResponse(item.Id, item.NamaLengkap, item.NomorIndukKaryawan, item.Email, item.StatusKeanggotaan, item.DibuatPada))
        .ToListAsync()))
    .RequireAuthorization("Pengurus");

app.MapPost("/api/admin/anggota/{id:int}/persetujuan", async (int id, PutusanPengajuanRequest request, ClaimsPrincipal principal, KkcsDbContext db, SimpananService simpananService, JurnalService jurnalService, AuditService audit) =>
{
    var pengguna = await db.Pengguna.FirstOrDefaultAsync(item => item.Id == id);
    if (pengguna is null) return Results.NotFound();
    if (pengguna.StatusKeanggotaan == "Aktif") return Results.BadRequest(new { message = "Anggota ini sudah aktif." });

    if (!request.Setuju)
    {
        pengguna.StatusKeanggotaan = "Ditolak";
        await db.SaveChangesAsync();
        await audit.CatatAsync(principal, "Pendaftaran", "Tolak", $"Menolak pendaftaran anggota {pengguna.NamaLengkap} (NIK {pengguna.NomorIndukKaryawan}).", pengguna.Id);
        return Results.Ok(new { message = "Pendaftaran ditolak." });
    }

    var konfigurasi = await db.KonfigurasiKoperasi.FirstAsync();
    pengguna.StatusKeanggotaan = "Aktif";
    pengguna.DisetujuiPada = DateTime.UtcNow;

    var pokok = await simpananService.DapatkanAtauBuatAsync(pengguna.Id, "POKOK");
    if (pokok.Saldo < konfigurasi.SimpananPokokNominal)
    {
        var setoran = konfigurasi.SimpananPokokNominal - pokok.Saldo;
        SimpananService.Catat(pokok, "Setor", setoran, "Setoran pokok keanggotaan");
        await jurnalService.PostingOtomatisAsync(DateTime.UtcNow.Date, $"Simpanan pokok anggota baru {pengguna.NamaLengkap}", "Simpanan", $"pengguna:{pengguna.Id}",
            BarisJurnal.D(KodeAkun.Kas, setoran), BarisJurnal.K(KodeAkun.SimpananPokok, setoran));
    }
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Pendaftaran", "Setujui",
        $"Menyetujui pendaftaran anggota {pengguna.NamaLengkap} (NIK {pengguna.NomorIndukKaryawan}); simpanan pokok {konfigurasi.SimpananPokokNominal:N0} dikreditkan.", pengguna.Id);
    return Results.Ok(new { message = $"Pendaftaran disetujui. Simpanan pokok {konfigurasi.SimpananPokokNominal:N0} dikreditkan." });
}).RequireAuthorization("Pengurus");

// ── Pengurus: Direktori anggota & profil 360° (simpanan, pinjaman, belanja) ──
app.MapGet("/api/admin/anggota/direktori", async (KkcsDbContext db, HttpResponse response, string? cari, string? peran, int? halaman, int? ukuran) =>
{
    var saldoPerAnggota = await db.Simpanan.AsNoTracking()
        .GroupBy(item => item.PenggunaId)
        .Select(g => new { PenggunaId = g.Key, Total = g.Sum(item => item.Saldo) })
        .ToDictionaryAsync(item => item.PenggunaId, item => item.Total);

    var berjangkaAktifPerAnggota = await db.SimpananBerjangka.AsNoTracking()
        .Where(item => item.Status == "Aktif" || item.Status == "JatuhTempo")
        .GroupBy(item => item.PenggunaId)
        .Select(g => new { PenggunaId = g.Key, Total = g.Sum(item => item.Nominal) })
        .ToDictionaryAsync(item => item.PenggunaId, item => item.Total);

    var idAktifSemua = await db.Pengguna.AsNoTracking().Where(item => item.StatusKeanggotaan == "Aktif").Select(item => item.Id).ToListAsync();
    var totalSimpananSemua = idAktifSemua.Sum(id => saldoPerAnggota.GetValueOrDefault(id) + berjangkaAktifPerAnggota.GetValueOrDefault(id));
    response.Headers["X-Total-Simpanan"] = totalSimpananSemua.ToString(System.Globalization.CultureInfo.InvariantCulture);

    var query = db.Pengguna.AsNoTracking().Where(item => item.StatusKeanggotaan == "Aktif");
    if (!string.IsNullOrWhiteSpace(cari))
    {
        var needle = cari.Trim();
        query = query.Where(item => item.NamaLengkap.Contains(needle) || item.NomorIndukKaryawan.Contains(needle) || (item.Email != null && item.Email.Contains(needle)));
    }
    if (!string.IsNullOrWhiteSpace(peran)) query = query.Where(item => item.Peran == peran);
    query = query.OrderBy(item => item.NamaLengkap);

    if (ukuran is > 0)
    {
        var total = await query.CountAsync();
        var ukuranHalaman = Math.Min(ukuran.Value, 200);
        var nomorHalaman = halaman is > 0 ? halaman.Value : 1;
        query = query.Skip((nomorHalaman - 1) * ukuranHalaman).Take(ukuranHalaman);
        response.Headers["X-Total-Count"] = total.ToString();
    }

    var data = await query
        .Select(item => new { item.Id, item.NamaLengkap, item.NomorIndukKaryawan, item.Email, item.Peran, item.StatusKeanggotaan, item.Aktif, item.DibuatPada })
        .ToListAsync();

    return Results.Ok(data.Select(item => new AnggotaDirektoriResponse(
        item.Id, item.NamaLengkap, item.NomorIndukKaryawan, item.Email, item.Peran, item.StatusKeanggotaan, item.Aktif,
        (saldoPerAnggota.GetValueOrDefault(item.Id)) + berjangkaAktifPerAnggota.GetValueOrDefault(item.Id),
        item.DibuatPada)));
}).RequireAuthorization("Pengurus");

app.MapGet("/api/admin/anggota/{id:int}/detail", async (int id, KkcsDbContext db) =>
{
    var detail = await BuatAnggotaDetailAsync(id, db);
    return detail is null ? Results.NotFound() : Results.Ok(detail);
}).RequireAuthorization("Pengurus");

app.MapGet("/api/admin/anggota/{id:int}/detail/pdf", async (int id, KkcsDbContext db) =>
{
    var detail = await BuatAnggotaDetailAsync(id, db);
    if (detail is null) return Results.NotFound();
    var pdf = AnggotaDetailPdf.Buat(detail);
    return Results.File(pdf, "application/pdf", $"Laporan-Anggota-{detail.NomorIndukKaryawan}.pdf");
}).RequireAuthorization("Pengurus");

app.MapGet("/api/admin/panduan/pdf", () =>
    Results.File(PanduanPengurusPdf.Buat(), "application/pdf", "Manual-Book-Pengurus-KKCS.pdf"))
    .RequireAuthorization("Pengurus");

// ── Admin: Simpanan Wajib ────────────────────────────────────────────────────
app.MapGet("/api/admin/simpanan/wajib", async (KkcsDbContext db) =>
    Results.Ok(await db.TagihanWajib.AsNoTracking().Include(item => item.Pengguna)
        .OrderByDescending(item => item.Status == "Ditagih").ThenByDescending(item => item.Periode).ThenBy(item => item.Pengguna.NamaLengkap)
        .Select(item => new AdminTagihanWajibResponse(
            item.Id, item.Pengguna.NamaLengkap, item.Pengguna.NomorIndukKaryawan,
            item.Periode, item.Nominal, item.JatuhTempo, item.Status, item.CatatanReview, item.DibuatPada, item.DiprosesPada))
        .ToListAsync()))
    .RequireAuthorization("Pengurus");

app.MapPost("/api/admin/simpanan/wajib/generate", async (KkcsDbContext db) =>
{
    var konfigurasi = await db.KonfigurasiKoperasi.FirstAsync();
    var periode = TagihanWajibGenerator.PeriodeSekarang();
    var dibuat = await TagihanWajibGenerator.GenerateAsync(db, konfigurasi, periode);
    return Results.Ok(new { message = $"{dibuat} tagihan periode {periode} dibuat.", periode, dibuat });
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/simpanan/wajib/{id:int}/putusan", async (int id, PutusanPengajuanRequest request, ClaimsPrincipal principal, KkcsDbContext db, SimpananService simpananService, JurnalService jurnalService, AuditService audit) =>
{
    var tagihan = await db.TagihanWajib.Include(item => item.Pengguna).FirstOrDefaultAsync(item => item.Id == id);
    if (tagihan is null) return Results.NotFound();
    if (tagihan.Status != "Ditagih") return Results.BadRequest(new { message = "Tagihan ini sudah diproses." });

    tagihan.CatatanReview = string.IsNullOrWhiteSpace(request.Catatan) ? null : request.Catatan.Trim();
    tagihan.DiprosesPada = DateTime.UtcNow;
    tagihan.Status = request.Setuju ? "Dibayar" : "Ditolak";

    if (request.Setuju)
    {
        var wajib = await simpananService.DapatkanAtauBuatAsync(tagihan.PenggunaId, "WAJIB");
        SimpananService.Catat(wajib, "Setor", tagihan.Nominal, $"Simpanan wajib {tagihan.Periode}");
        await jurnalService.PostingOtomatisAsync(DateTime.UtcNow.Date, $"Simpanan wajib {tagihan.Periode} — {tagihan.Pengguna.NamaLengkap}", "Simpanan", $"tagihanWajib:{tagihan.Id}",
            BarisJurnal.D(KodeAkun.Kas, tagihan.Nominal), BarisJurnal.K(KodeAkun.SimpananWajib, tagihan.Nominal));
    }
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Simpanan", request.Setuju ? "Setujui" : "Tolak",
        $"{(request.Setuju ? "Menyetujui" : "Menolak")} tagihan simpanan wajib {tagihan.Periode} milik {tagihan.Pengguna.NamaLengkap} (Rp {tagihan.Nominal:N0}).", tagihan.Id);
    return Results.Ok(new { message = request.Setuju ? "Tagihan wajib disetujui." : "Tagihan wajib ditolak." });
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/simpanan/wajib/setujui-periode", async (SetujuiPeriodeRequest request, ClaimsPrincipal principal, KkcsDbContext db, SimpananService simpananService, JurnalService jurnalService, AuditService audit) =>
{
    var periode = request.Periode?.Trim();
    if (string.IsNullOrWhiteSpace(periode)) return Results.BadRequest(new { message = "Periode wajib diisi (format yyyy-MM)." });

    var target = await db.TagihanWajib.Where(item => item.Periode == periode && item.Status == "Ditagih").ToListAsync();
    decimal totalDikreditkan = 0;
    foreach (var tagihan in target)
    {
        tagihan.Status = "Dibayar";
        tagihan.DiprosesPada = DateTime.UtcNow;
        var wajib = await simpananService.DapatkanAtauBuatAsync(tagihan.PenggunaId, "WAJIB");
        SimpananService.Catat(wajib, "Setor", tagihan.Nominal, $"Simpanan wajib {tagihan.Periode}");
        totalDikreditkan += tagihan.Nominal;
    }
    if (totalDikreditkan > 0)
    {
        await jurnalService.PostingOtomatisAsync(DateTime.UtcNow.Date, $"Simpanan wajib periode {periode} ({target.Count} anggota)", "Simpanan", $"wajibPeriode:{periode}",
            BarisJurnal.D(KodeAkun.Kas, totalDikreditkan), BarisJurnal.K(KodeAkun.SimpananWajib, totalDikreditkan));
    }
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Simpanan", "SetujuiPeriode",
        $"Menyetujui massal {target.Count} tagihan simpanan wajib periode {periode} (total Rp {totalDikreditkan:N0}).", null, new { periode, jumlah = target.Count, total = totalDikreditkan });
    return Results.Ok(new { message = $"{target.Count} tagihan wajib periode {periode} disetujui.", jumlah = target.Count });
}).RequireAuthorization("Pengurus");

// ── Admin: Simpanan Sukarela ─────────────────────────────────────────────────
app.MapGet("/api/admin/simpanan/sukarela", async (KkcsDbContext db, SimpananService simpananService) =>
{
    var data = await db.TransaksiSukarela.AsNoTracking().Include(item => item.Pengguna)
        .OrderByDescending(item => item.Status == "Diajukan").ThenByDescending(item => item.DiajukanPada)
        .ToListAsync();

    // Posting bunga bulanan terakhir per anggota (kalau ada) — ditampilkan ringkas di tabel supaya
    // pengurus bisa lihat hasil "Hitung bunga bulan lalu" tanpa harus buka riwayat mutasi.
    var bungaTerakhirPerAnggota = await db.PostingBungaSukarela.AsNoTracking()
        .GroupBy(item => item.PenggunaId)
        .Select(g => g.OrderByDescending(item => item.Periode).First())
        .ToDictionaryAsync(item => item.PenggunaId);

    var result = new List<AdminTransaksiSukarelaResponse>();
    foreach (var item in data)
    {
        var bungaTerakhir = bungaTerakhirPerAnggota.GetValueOrDefault(item.PenggunaId);
        result.Add(new AdminTransaksiSukarelaResponse(
            item.Id, item.Pengguna.NamaLengkap, item.Pengguna.NomorIndukKaryawan,
            item.Jenis, item.Nominal, item.Catatan, item.Status, item.CatatanReview, item.DiajukanPada, item.DiprosesPada,
            await simpananService.SaldoAsync(item.PenggunaId, "SUKARELA"),
            bungaTerakhir is null ? null : new BungaSukarelaTerakhirResponse(
                bungaTerakhir.Periode, bungaTerakhir.BungaBruto, bungaTerakhir.Pajak, bungaTerakhir.BungaNeto),
            item.BuktiTransferUrl));
    }
    return Results.Ok(result);
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/simpanan/sukarela/{id:int}/putusan", async (int id, PutusanPengajuanRequest request, ClaimsPrincipal principal, KkcsDbContext db, SimpananService simpananService, JurnalService jurnalService, AuditService audit) =>
{
    var transaksi = await db.TransaksiSukarela.Include(item => item.Pengguna).FirstOrDefaultAsync(item => item.Id == id);
    if (transaksi is null) return Results.NotFound();
    if (transaksi.Status != "Diajukan") return Results.BadRequest(new { message = "Pengajuan ini sudah diproses." });

    transaksi.CatatanReview = string.IsNullOrWhiteSpace(request.Catatan) ? null : request.Catatan.Trim();
    transaksi.DiprosesPada = DateTime.UtcNow;

    if (!request.Setuju)
    {
        transaksi.Status = "Ditolak";
        await db.SaveChangesAsync();
        await audit.CatatAsync(principal, "Simpanan", "Tolak",
            $"Menolak {transaksi.Jenis.ToLower()} sukarela milik {transaksi.Pengguna.NamaLengkap} (Rp {transaksi.Nominal:N0}).", transaksi.Id);
        return Results.Ok(new { message = "Pengajuan simpanan sukarela ditolak." });
    }

    var sukarela = await simpananService.DapatkanAtauBuatAsync(transaksi.PenggunaId, "SUKARELA");
    if (transaksi.Jenis == "Tarik" && transaksi.Nominal > sukarela.Saldo)
    {
        return Results.BadRequest(new { message = $"Saldo sukarela anggota tidak cukup (saldo {sukarela.Saldo:N0})." });
    }
    SimpananService.Catat(sukarela, transaksi.Jenis, transaksi.Nominal,
        transaksi.Jenis == "Tarik" ? "Penarikan sukarela" : "Setoran sukarela");
    transaksi.Status = "Disetujui";

    var keteranganJurnal = $"{(transaksi.Jenis == "Tarik" ? "Penarikan" : "Setoran")} sukarela — {transaksi.Pengguna.NamaLengkap}";
    await jurnalService.PostingOtomatisAsync(DateTime.UtcNow.Date, keteranganJurnal, "Simpanan", $"sukarela:{transaksi.Id}",
        transaksi.Jenis == "Tarik"
            ? [BarisJurnal.D(KodeAkun.SimpananSukarela, transaksi.Nominal), BarisJurnal.K(KodeAkun.Kas, transaksi.Nominal)]
            : [BarisJurnal.D(KodeAkun.Kas, transaksi.Nominal), BarisJurnal.K(KodeAkun.SimpananSukarela, transaksi.Nominal)]);

    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Simpanan", "Setujui",
        $"Menyetujui {transaksi.Jenis.ToLower()} sukarela milik {transaksi.Pengguna.NamaLengkap} (Rp {transaksi.Nominal:N0}).", transaksi.Id);
    return Results.Ok(new { message = "Pengajuan simpanan sukarela disetujui." });
}).RequireAuthorization("Pengurus");

// ── Admin: Sukarela Rutin (setoran sukarela otomatis bulanan) ───────────────
app.MapGet("/api/admin/simpanan/sukarela-rutin", async (KkcsDbContext db) =>
    Results.Ok(await db.SukarelaRutin.AsNoTracking().Include(item => item.Pengguna)
        .OrderByDescending(item => item.Status == "Diajukan" || item.Status == "DihentikanDiajukan").ThenByDescending(item => item.DiajukanPada)
        .Select(item => new AdminSukarelaRutinResponse(
            item.Id, item.Pengguna.NamaLengkap, item.Pengguna.NomorIndukKaryawan, item.Nominal, item.TanggalSetor,
            item.Status, item.CatatanReview, item.DiajukanPada, item.DiputuskanPada, item.TerakhirDijalankanPeriode))
        .ToListAsync()))
    .RequireAuthorization("Pengurus");

app.MapPost("/api/admin/simpanan/sukarela-rutin/{id:int}/putusan", async (int id, PutusanPengajuanRequest request, ClaimsPrincipal principal, KkcsDbContext db, AuditService audit) =>
{
    var rutin = await db.SukarelaRutin.Include(item => item.Pengguna).FirstOrDefaultAsync(item => item.Id == id);
    if (rutin is null) return Results.NotFound();
    if (rutin.Status != "Diajukan") return Results.BadRequest(new { message = "Pengajuan ini sudah diproses." });

    rutin.CatatanReview = string.IsNullOrWhiteSpace(request.Catatan) ? null : request.Catatan.Trim();
    rutin.DiputuskanPada = DateTime.UtcNow;
    rutin.Status = request.Setuju ? "Aktif" : "Ditolak";
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Simpanan", request.Setuju ? "Setujui" : "Tolak",
        $"{(request.Setuju ? "Menyetujui" : "Menolak")} Sukarela Rutin milik {rutin.Pengguna.NamaLengkap} (Rp {rutin.Nominal:N0}/bulan, tgl {rutin.TanggalSetor}).", rutin.Id);
    return Results.Ok(new { message = request.Setuju ? "Sukarela Rutin disetujui dan akan aktif otomatis." : "Pengajuan Sukarela Rutin ditolak." });
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/simpanan/sukarela-rutin/{id:int}/putusan-berhenti", async (int id, PutusanPengajuanRequest request, ClaimsPrincipal principal, KkcsDbContext db, AuditService audit) =>
{
    var rutin = await db.SukarelaRutin.Include(item => item.Pengguna).FirstOrDefaultAsync(item => item.Id == id);
    if (rutin is null) return Results.NotFound();
    if (rutin.Status != "DihentikanDiajukan") return Results.BadRequest(new { message = "Tidak ada pengajuan berhenti yang menunggu untuk instruksi ini." });

    rutin.CatatanReview = string.IsNullOrWhiteSpace(request.Catatan) ? null : request.Catatan.Trim();
    rutin.DiputuskanPada = DateTime.UtcNow;
    rutin.Status = request.Setuju ? "Dihentikan" : "Aktif";
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Simpanan", request.Setuju ? "HentikanRutin" : "TolakBerhentiRutin",
        $"{(request.Setuju ? "Menghentikan" : "Menolak permintaan berhenti")} Sukarela Rutin milik {rutin.Pengguna.NamaLengkap}.", rutin.Id);
    return Results.Ok(new { message = request.Setuju ? "Sukarela Rutin dihentikan." : "Permintaan berhenti ditolak, instruksi tetap aktif." });
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/simpanan/sukarela-rutin/setujui-periode", async (SetujuiPeriodeRequest request, ClaimsPrincipal principal, KkcsDbContext db, SimpananService simpananService, JurnalService jurnalService, AuditService audit) =>
{
    var periode = string.IsNullOrWhiteSpace(request.Periode) ? TagihanWajibGenerator.PeriodeSekarang() : request.Periode.Trim();
    var jumlah = await SukarelaRutinRunner.JalankanPeriodeAsync(db, simpananService, jurnalService, periode);
    if (jumlah > 0)
        await audit.CatatAsync(principal, "Simpanan", "Setujui", $"Menjalankan {jumlah} setoran Sukarela Rutin periode {periode}.");
    return Results.Ok(new { message = jumlah > 0 ? $"{jumlah} setoran Sukarela Rutin periode {periode} berhasil diproses." : "Tidak ada setoran Sukarela Rutin yang perlu diproses periode ini." });
}).RequireAuthorization("Pengurus");

// ── Admin: Simpanan Berjangka ────────────────────────────────────────────────
app.MapGet("/api/admin/simpanan/berjangka/produk", async (KkcsDbContext db) =>
    Results.Ok(await db.ProdukBerjangka.AsNoTracking().OrderByDescending(item => item.Aktif).ThenBy(item => item.Nominal)
        .Select(item => new ProdukBerjangkaResponse(item.Id, item.Nama, item.Nominal, item.TenorBulan, item.Aktif))
        .ToListAsync()))
    .RequireAuthorization("Pengurus");

app.MapPost("/api/admin/simpanan/berjangka/produk", async (ProdukBerjangkaRequest request, KkcsDbContext db) =>
{
    if (string.IsNullOrWhiteSpace(request.Nama) || request.Nominal <= 0 || request.TenorBulan <= 0)
    {
        return Results.BadRequest(new { message = "Nama, nominal, dan tenor wajib diisi dengan benar." });
    }
    var produk = new ProdukBerjangka
    {
        Nama = request.Nama.Trim(),
        Nominal = request.Nominal,
        TenorBulan = request.TenorBulan,
        Aktif = true
    };
    db.ProdukBerjangka.Add(produk);
    await db.SaveChangesAsync();
    return Results.Ok(new ProdukBerjangkaResponse(produk.Id, produk.Nama, produk.Nominal, produk.TenorBulan, produk.Aktif));
}).RequireAuthorization("Pengurus");

app.MapPatch("/api/admin/simpanan/berjangka/produk/{id:int}", async (int id, ToggleUserStatusRequest request, KkcsDbContext db) =>
{
    var produk = await db.ProdukBerjangka.FirstOrDefaultAsync(item => item.Id == id);
    if (produk is null) return Results.NotFound();
    produk.Aktif = request.Aktif;
    await db.SaveChangesAsync();
    return Results.Ok(new ProdukBerjangkaResponse(produk.Id, produk.Nama, produk.Nominal, produk.TenorBulan, produk.Aktif));
}).RequireAuthorization("Pengurus");

app.MapGet("/api/admin/simpanan/berjangka", async (KkcsDbContext db) =>
{
    var konfigurasi = await db.KonfigurasiKoperasi.AsNoTracking().FirstAsync();
    var data = await db.SimpananBerjangka.AsNoTracking().Include(item => item.Pengguna).Include(item => item.Produk)
        .OrderByDescending(item => item.Status == "Diajukan").ThenByDescending(item => item.Status == "JatuhTempo").ThenByDescending(item => item.DiajukanPada)
        .ToListAsync();
    return Results.Ok(data.Select(item =>
    {
        var estimasiBunga = item.BungaDibayar ?? BungaDeposito.Hitung(item.Nominal, konfigurasi.BungaDepositoTahunan, item.TenorBulan);
        var estimasiPajak = item.PajakBunga ?? Math.Round(estimasiBunga * konfigurasi.TarifPph, 2, MidpointRounding.AwayFromZero);
        var estimasiNeto = item.BungaNeto ?? (estimasiBunga - estimasiPajak);
        return new AdminBerjangkaResponse(
            item.Id, item.Pengguna.NamaLengkap, item.Pengguna.NomorIndukKaryawan, item.Produk.Nama,
            item.NomorSertifikat, item.Nominal, item.TenorBulan, item.Status, item.CatatanReview,
            item.DiajukanPada, item.TanggalMulai, item.TanggalJatuhTempo, item.DicairkanPada,
            estimasiBunga, estimasiPajak, estimasiNeto, item.PajakBunga != null,
            item.PencairanDiajukan, item.PencairanDiajukanPada, item.AlasanPencairan, item.BuktiTransferUrl);
    }).ToList());
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/simpanan/berjangka/{id:int}/putusan", async (int id, PutusanPengajuanRequest request, ClaimsPrincipal principal, KkcsDbContext db, JurnalService jurnalService, AuditService audit) =>
{
    var berjangka = await db.SimpananBerjangka.Include(item => item.Pengguna).FirstOrDefaultAsync(item => item.Id == id);
    if (berjangka is null) return Results.NotFound();
    if (berjangka.Status != "Diajukan") return Results.BadRequest(new { message = "Pengajuan ini sudah diproses." });

    berjangka.CatatanReview = string.IsNullOrWhiteSpace(request.Catatan) ? null : request.Catatan.Trim();
    if (!request.Setuju)
    {
        berjangka.Status = "Ditolak";
        await db.SaveChangesAsync();
        await audit.CatatAsync(principal, "Simpanan", "Tolak",
            $"Menolak simpanan berjangka {berjangka.NomorSertifikat} milik {berjangka.Pengguna.NamaLengkap} (Rp {berjangka.Nominal:N0}).", berjangka.Id);
        return Results.Ok(new { message = "Pengajuan simpanan berjangka ditolak." });
    }

    var mulai = (request.TanggalMulai ?? DateTime.UtcNow).Date;
    berjangka.Status = "Aktif";
    berjangka.TanggalMulai = mulai;
    berjangka.TanggalJatuhTempo = mulai.AddMonths(berjangka.TenorBulan);

    await jurnalService.PostingOtomatisAsync(mulai, $"Simpanan berjangka {berjangka.NomorSertifikat} — {berjangka.Pengguna.NamaLengkap}", "Simpanan", $"berjangka:{berjangka.Id}",
        BarisJurnal.D(KodeAkun.Kas, berjangka.Nominal), BarisJurnal.K(KodeAkun.SimpananBerjangka, berjangka.Nominal));

    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Simpanan", "Setujui",
        $"Menyetujui & mengaktifkan simpanan berjangka {berjangka.NomorSertifikat} milik {berjangka.Pengguna.NamaLengkap} (Rp {berjangka.Nominal:N0}, {berjangka.TenorBulan} bulan).", berjangka.Id);
    return Results.Ok(new { message = "Simpanan berjangka diaktifkan." });
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/simpanan/berjangka/{id:int}/pencairan", async (int id, ClaimsPrincipal principal, KkcsDbContext db, SimpananService simpananService, JurnalService jurnalService, AuditService audit) =>
{
    var berjangka = await db.SimpananBerjangka.Include(item => item.Pengguna).FirstOrDefaultAsync(item => item.Id == id);
    if (berjangka is null) return Results.NotFound();

    var dipercepat = berjangka.Status == "Aktif";
    if (berjangka.Status is not ("Aktif" or "JatuhTempo"))
    {
        return Results.BadRequest(new { message = "Hanya simpanan berjangka aktif / jatuh tempo yang dapat dicairkan." });
    }
    if (dipercepat && !berjangka.PencairanDiajukan)
    {
        return Results.BadRequest(new { message = "Belum ada pengajuan pencairan dipercepat dari anggota." });
    }

    var konfigurasi = await db.KonfigurasiKoperasi.FirstAsync();
    // Pencairan dipercepat (sebelum jatuh tempo): anggota tidak mendapatkan bunga.
    var bunga = dipercepat ? 0m : BungaDeposito.Hitung(berjangka.Nominal, konfigurasi.BungaDepositoTahunan, berjangka.TenorBulan);
    var pajak = bunga > 0 ? Math.Round(bunga * konfigurasi.TarifPph, 2, MidpointRounding.AwayFromZero) : 0m;
    var bungaNeto = bunga - pajak;

    var sukarela = await simpananService.DapatkanAtauBuatAsync(berjangka.PenggunaId, "SUKARELA");
    var keterangan = dipercepat
        ? $"Pencairan dipercepat berjangka {berjangka.NomorSertifikat} (pokok {berjangka.Nominal:N0}, tanpa bunga)"
        : $"Pencairan berjangka {berjangka.NomorSertifikat} (pokok {berjangka.Nominal:N0} + bunga neto {bungaNeto:N0}, PPh {pajak:N0})";
    SimpananService.Catat(sukarela, "Setor", berjangka.Nominal + bungaNeto, keterangan);

    berjangka.Status = "Dicairkan";
    berjangka.DicairkanPada = DateTime.UtcNow;
    berjangka.BungaDibayar = bunga; // tetap bruto — konsisten dengan pola bunga sukarela (dicatat penuh, pajak dipotong terpisah).
    berjangka.PajakBunga = pajak;
    berjangka.BungaNeto = bungaNeto;

    // Reklasifikasi internal: pokok (+bunga neto bila ada) pindah dari Simpanan Berjangka ke Simpanan Sukarela — bukan kas keluar.
    // PPh atas bunga bruto dibukukan sebagai Utang PPh, sama seperti posting bunga sukarela bulanan.
    var barisPencairan = bunga > 0
        ? new[]
          {
              BarisJurnal.D(KodeAkun.SimpananBerjangka, berjangka.Nominal),
              BarisJurnal.D(KodeAkun.BebanBungaBerjangka, bunga),
              BarisJurnal.K(KodeAkun.SimpananSukarela, berjangka.Nominal + bungaNeto),
              BarisJurnal.K(KodeAkun.UtangPph, pajak)
          }
        : [BarisJurnal.D(KodeAkun.SimpananBerjangka, berjangka.Nominal), BarisJurnal.K(KodeAkun.SimpananSukarela, berjangka.Nominal)];
    await jurnalService.PostingOtomatisAsync(DateTime.UtcNow.Date, $"{keterangan} — {berjangka.Pengguna.NamaLengkap}", "Simpanan", $"pencairanBerjangka:{berjangka.Id}", barisPencairan);

    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Simpanan", "Cairkan",
        $"Mencairkan simpanan berjangka {berjangka.NomorSertifikat} milik {berjangka.Pengguna.NamaLengkap} ({(dipercepat ? "dipercepat, tanpa bunga" : "jatuh tempo")}, pokok Rp {berjangka.Nominal:N0} + bunga neto Rp {bungaNeto:N0}, PPh Rp {pajak:N0}).", berjangka.Id);
    return Results.Ok(new
    {
        message = dipercepat
            ? $"Pencairan dipercepat disetujui. Pokok {berjangka.Nominal:N0} (tanpa bunga) masuk ke Simpanan Sukarela."
            : $"Simpanan berjangka dicairkan. Pokok + bunga neto {(berjangka.Nominal + bungaNeto):N0} (PPh {pajak:N0}) masuk ke Simpanan Sukarela."
    });
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/simpanan/berjangka/{id:int}/pencairan/tolak", async (int id, ClaimsPrincipal principal, KkcsDbContext db, AuditService audit) =>
{
    var berjangka = await db.SimpananBerjangka.Include(item => item.Pengguna).FirstOrDefaultAsync(item => item.Id == id);
    if (berjangka is null) return Results.NotFound();
    if (!berjangka.PencairanDiajukan || berjangka.Status != "Aktif")
    {
        return Results.BadRequest(new { message = "Tidak ada pengajuan pencairan dipercepat untuk ditolak." });
    }
    berjangka.PencairanDiajukan = false;
    berjangka.PencairanDiajukanPada = null;
    berjangka.AlasanPencairan = null;
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "Simpanan", "Tolak",
        $"Menolak pengajuan pencairan dipercepat berjangka {berjangka.NomorSertifikat} milik {berjangka.Pengguna.NamaLengkap}.", berjangka.Id);
    return Results.Ok(new { message = "Pengajuan pencairan dipercepat ditolak. Simpanan berjangka tetap aktif." });
}).RequireAuthorization("Pengurus");

app.MapGet("/api/erat/agenda", async (ClaimsPrincipal principal, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();
    var agenda = await db.EratAgenda.AsNoTracking().Include(item => item.Opsi).ThenInclude(o => o.Suara)
        .Where(item => item.Status == "Aktif" || item.Status == "Selesai")
        .OrderByDescending(item => item.Status == "Aktif").ThenByDescending(item => item.MulaiPada ?? item.DibuatPada)
        .ToListAsync();
    var suaraSaya = await db.EratSuara.AsNoTracking()
        .Where(s => s.PenggunaId == pengguna.Id)
        .ToDictionaryAsync(s => s.EratAgendaId, s => s.EratOpsiId);
    return Results.Ok(agenda.Select(item => ToEratAgendaResponse(item, suaraSaya.GetValueOrDefault(item.Id, 0))).ToList());
}).RequireAuthorization();

app.MapPost("/api/erat/agenda/{agendaId:int}/suara", async (int agendaId, ClaimsPrincipal principal, EratVoteRequest request, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();
    var agenda = await db.EratAgenda.AsNoTracking().FirstOrDefaultAsync(item => item.Id == agendaId && item.Status == "Aktif");
    if (agenda is null) return Results.NotFound(new { message = "Agenda E-RAT tidak aktif atau tidak ditemukan." });
    var opsi = await db.EratOpsi.AsNoTracking().FirstOrDefaultAsync(item => item.Id == request.OpsiId && item.EratAgendaId == agendaId);
    if (opsi is null) return Results.BadRequest(new { message = "Pilihan voting tidak valid." });
    if (await db.EratSuara.AnyAsync(suara => suara.EratAgendaId == agendaId && suara.PenggunaId == pengguna.Id))
    {
        return Results.Conflict(new { message = "Anda sudah memberikan suara pada agenda ini." });
    }

    db.EratSuara.Add(new EratSuara { EratAgendaId = agendaId, EratOpsiId = opsi.Id, PenggunaId = pengguna.Id });
    await db.SaveChangesAsync();
    return Results.Ok(new { message = "Suara berhasil dicatat." });
}).RequireAuthorization();

app.MapGet("/api/erat/laporan-tahunan", async (ClaimsPrincipal principal, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    // Anggota hanya melihat dokumen RAT tahun terbaru; arsip tahun lama khusus pengurus di Admin Console.
    var tahunTerbaru = await db.LaporanTahunan.AsNoTracking()
        .Where(item => item.Aktif)
        .Select(item => (int?)item.Tahun)
        .MaxAsync();
    if (tahunTerbaru is null) return Results.Ok(new List<LaporanResponse>());

    var laporan = await db.LaporanTahunan.AsNoTracking()
        .Where(item => item.Aktif && item.Tahun == tahunTerbaru)
        .OrderByDescending(item => item.DiterbitkanPada)
        .Select(item => new LaporanResponse(item.Id, item.Tahun, item.Judul, item.Deskripsi, item.FileUrl, item.DiterbitkanPada))
        .ToListAsync();
    return Results.Ok(laporan);
}).RequireAuthorization();

// Laporan RAT otomatis yang sudah ditayangkan pengurus (tahun buku terbaru yang dipublikasikan).
app.MapGet("/api/erat/laporan-rat-tahunan", async (ClaimsPrincipal principal, KkcsDbContext db) =>
{
    var pengguna = await FindActiveMember(principal, db);
    if (pengguna is null) return BelumAktif();

    var tahunTerbit = await db.RatTahunan.AsNoTracking()
        .Where(item => item.Dipublikasikan)
        .Select(item => (int?)item.Tahun)
        .MaxAsync();
    if (tahunTerbit is null) return Results.NotFound();

    return Results.Ok(await BuatLaporanRatAsync(db, tahunTerbit.Value));
}).RequireAuthorization();

// Unduh berkas dokumen RAT (anonim, memaksa download via Content-Disposition: attachment).
app.MapGet("/api/erat/laporan-tahunan/{id:int}/berkas", async (int id, KkcsDbContext db, IWebHostEnvironment environment) =>
{
    var laporan = await db.LaporanTahunan.AsNoTracking().FirstOrDefaultAsync(item => item.Id == id && item.Aktif);
    if (laporan is null) return Results.NotFound();

    var webRoot = environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot");
    var path = Path.Combine(webRoot, laporan.FileUrl.TrimStart('/').Replace('/', Path.DirectorySeparatorChar));
    if (!File.Exists(path)) return Results.NotFound();

    var judulBersih = string.Join("-", laporan.Judul.Split(Path.GetInvalidFileNameChars(), StringSplitOptions.RemoveEmptyEntries));
    return Results.File(path, "application/pdf", $"RAT-{laporan.Tahun}-{judulBersih}.pdf", enableRangeProcessing: true);
});

// ── Admin: E-RAT voting ─────────────────────────────────────────────────────
app.MapGet("/api/admin/erat/agenda", async (KkcsDbContext db) =>
{
    var agenda = await db.EratAgenda.AsNoTracking().Include(item => item.Opsi).ThenInclude(o => o.Suara)
        .OrderByDescending(item => item.DibuatPada)
        .ToListAsync();
    return Results.Ok(agenda.Select(item => ToEratAgendaResponse(item, 0)).ToList());
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/erat/agenda", async (EratAgendaRequest request, KkcsDbContext db) =>
{
    var opsi = (request.Opsi ?? []).Select(o => o?.Trim()).Where(o => !string.IsNullOrWhiteSpace(o)).Cast<string>().ToList();
    if (string.IsNullOrWhiteSpace(request.Judul) || opsi.Count < 2)
    {
        return Results.BadRequest(new { message = "Judul wajib diisi dan minimal 2 pilihan." });
    }
    var agenda = new EratAgenda
    {
        Judul = request.Judul.Trim(),
        Deskripsi = string.IsNullOrWhiteSpace(request.Deskripsi) ? null : request.Deskripsi.Trim(),
        Status = "Draft",
        MulaiPada = request.MulaiPada,
        SelesaiPada = request.SelesaiPada,
        Opsi = opsi.Select((label, index) => new EratOpsi { Label = label, Urutan = index }).ToList()
    };
    db.EratAgenda.Add(agenda);
    await db.SaveChangesAsync();
    await db.Entry(agenda).Collection(a => a.Opsi).LoadAsync();
    return Results.Ok(ToEratAgendaResponse(agenda, 0));
}).RequireAuthorization("Pengurus");

app.MapPut("/api/admin/erat/agenda/{id:int}", async (int id, EratAgendaRequest request, KkcsDbContext db) =>
{
    var agenda = await db.EratAgenda.Include(item => item.Opsi).ThenInclude(o => o.Suara).FirstOrDefaultAsync(item => item.Id == id);
    if (agenda is null) return Results.NotFound();
    if (string.IsNullOrWhiteSpace(request.Judul)) return Results.BadRequest(new { message = "Judul wajib diisi." });
    agenda.Judul = request.Judul.Trim();
    agenda.Deskripsi = string.IsNullOrWhiteSpace(request.Deskripsi) ? null : request.Deskripsi.Trim();
    agenda.MulaiPada = request.MulaiPada;
    agenda.SelesaiPada = request.SelesaiPada;
    await db.SaveChangesAsync();
    return Results.Ok(ToEratAgendaResponse(agenda, 0));
}).RequireAuthorization("Pengurus");

app.MapPost("/api/admin/erat/agenda/{id:int}/opsi", async (int id, EratOpsiRequest request, KkcsDbContext db) =>
{
    var agenda = await db.EratAgenda.Include(item => item.Opsi).ThenInclude(o => o.Suara).FirstOrDefaultAsync(item => item.Id == id);
    if (agenda is null) return Results.NotFound();
    if (agenda.Opsi.Any(o => o.Suara.Count > 0)) return Results.BadRequest(new { message = "Tidak bisa mengubah pilihan setelah ada suara masuk." });
    if (string.IsNullOrWhiteSpace(request.Label)) return Results.BadRequest(new { message = "Label pilihan wajib diisi." });
    agenda.Opsi.Add(new EratOpsi { Label = request.Label.Trim(), Urutan = agenda.Opsi.Count });
    await db.SaveChangesAsync();
    return Results.Ok(ToEratAgendaResponse(agenda, 0));
}).RequireAuthorization("Pengurus");

app.MapDelete("/api/admin/erat/agenda/{id:int}/opsi/{opsiId:int}", async (int id, int opsiId, KkcsDbContext db) =>
{
    var agenda = await db.EratAgenda.Include(item => item.Opsi).ThenInclude(o => o.Suara).FirstOrDefaultAsync(item => item.Id == id);
    if (agenda is null) return Results.NotFound();
    if (agenda.Opsi.Any(o => o.Suara.Count > 0)) return Results.BadRequest(new { message = "Tidak bisa mengubah pilihan setelah ada suara masuk." });
    if (agenda.Opsi.Count <= 2) return Results.BadRequest(new { message = "Minimal 2 pilihan." });
    var opsi = agenda.Opsi.FirstOrDefault(o => o.Id == opsiId);
    if (opsi is null) return Results.NotFound();
    agenda.Opsi.Remove(opsi);
    await db.SaveChangesAsync();
    return Results.Ok(ToEratAgendaResponse(agenda, 0));
}).RequireAuthorization("Pengurus");

app.MapPatch("/api/admin/erat/agenda/{id:int}/status", async (int id, EratStatusRequest request, ClaimsPrincipal principal, KkcsDbContext db, AuditService audit) =>
{
    var agenda = await db.EratAgenda.Include(item => item.Opsi).ThenInclude(o => o.Suara).FirstOrDefaultAsync(item => item.Id == id);
    if (agenda is null) return Results.NotFound();
    var status = request.Status?.Trim();
    if (status is not ("Draft" or "Aktif" or "Selesai")) return Results.BadRequest(new { message = "Status harus Draft, Aktif, atau Selesai." });
    if (status == "Aktif" && agenda.Opsi.Count < 2) return Results.BadRequest(new { message = "Minimal 2 pilihan sebelum ditayangkan." });
    var statusLama = agenda.Status;
    agenda.Status = status;
    if (status == "Aktif" && agenda.MulaiPada is null) agenda.MulaiPada = DateTime.UtcNow;
    if (status == "Selesai" && agenda.SelesaiPada is null) agenda.SelesaiPada = DateTime.UtcNow;
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "ERAT", "UbahStatus",
        $"Mengubah status agenda E-RAT \"{agenda.Judul}\" dari {statusLama} menjadi {agenda.Status}.", agenda.Id);
    return Results.Ok(ToEratAgendaResponse(agenda, 0));
}).RequireAuthorization("Pengurus");

app.MapDelete("/api/admin/erat/agenda/{id:int}", async (int id, KkcsDbContext db) =>
{
    var agenda = await db.EratAgenda.Include(item => item.Opsi).ThenInclude(o => o.Suara).FirstOrDefaultAsync(item => item.Id == id);
    if (agenda is null) return Results.NotFound();
    if (agenda.Opsi.Any(o => o.Suara.Count > 0)) return Results.BadRequest(new { message = "Tidak bisa menghapus agenda yang sudah memiliki suara." });
    db.EratAgenda.Remove(agenda);
    await db.SaveChangesAsync();
    return Results.Ok(new { message = "Agenda dihapus." });
}).RequireAuthorization("Pengurus");

// ── Admin: Dokumen RAT ──────────────────────────────────────────────────────
app.MapGet("/api/admin/erat/laporan", async (KkcsDbContext db) =>
    Results.Ok(await db.LaporanTahunan.AsNoTracking()
        .OrderByDescending(item => item.Tahun).ThenByDescending(item => item.DiterbitkanPada)
        .Select(item => new AdminLaporanResponse(item.Id, item.Tahun, item.Judul, item.Deskripsi, item.FileUrl, item.DiterbitkanPada, item.Aktif))
        .ToListAsync()))
    .RequireAuthorization("Pengurus");

app.MapPost("/api/admin/erat/laporan", async (HttpRequest request, KkcsDbContext db, IWebHostEnvironment environment) =>
{
    if (!request.HasFormContentType) return Results.BadRequest(new { message = "Kirim sebagai multipart/form-data." });
    var form = await request.ReadFormAsync();
    var file = form.Files["file"];
    if (file is null) return Results.BadRequest(new { message = "File dokumen (PDF) wajib diunggah." });
    var judul = form["judul"].ToString().Trim();
    if (string.IsNullOrWhiteSpace(judul)) return Results.BadRequest(new { message = "Judul wajib diisi." });
    var tahun = int.TryParse(form["tahun"], out var t) ? t : DateTime.Now.Year;
    var deskripsi = form["deskripsi"].ToString().Trim();

    var url = await SimpanDokumenAsync(file, environment, "rat");
    if (url is null) return Results.BadRequest(new { message = "Dokumen harus berformat PDF dan maksimal 20 MB." });

    var laporan = new LaporanTahunan
    {
        Tahun = tahun,
        Judul = judul,
        Deskripsi = string.IsNullOrWhiteSpace(deskripsi) ? null : deskripsi,
        FileUrl = url,
        Aktif = true
    };
    db.LaporanTahunan.Add(laporan);
    await db.SaveChangesAsync();
    return Results.Ok(new AdminLaporanResponse(laporan.Id, laporan.Tahun, laporan.Judul, laporan.Deskripsi, laporan.FileUrl, laporan.DiterbitkanPada, laporan.Aktif));
}).RequireAuthorization("Pengurus").DisableAntiforgery();

app.MapPatch("/api/admin/erat/laporan/{id:int}", async (int id, ToggleUserStatusRequest request, KkcsDbContext db) =>
{
    var laporan = await db.LaporanTahunan.FirstOrDefaultAsync(item => item.Id == id);
    if (laporan is null) return Results.NotFound();
    laporan.Aktif = request.Aktif;
    await db.SaveChangesAsync();
    return Results.Ok(new AdminLaporanResponse(laporan.Id, laporan.Tahun, laporan.Judul, laporan.Deskripsi, laporan.FileUrl, laporan.DiterbitkanPada, laporan.Aktif));
}).RequireAuthorization("Pengurus");

app.MapDelete("/api/admin/erat/laporan/{id:int}", async (int id, KkcsDbContext db, IWebHostEnvironment environment) =>
{
    var laporan = await db.LaporanTahunan.FirstOrDefaultAsync(item => item.Id == id);
    if (laporan is null) return Results.NotFound();
    HapusFoto(laporan.FileUrl, environment);
    db.LaporanTahunan.Remove(laporan);
    await db.SaveChangesAsync();
    return Results.Ok(new { message = "Dokumen dihapus." });
}).RequireAuthorization("Pengurus");

// ── Admin: Profil koperasi (Visi/Misi/sejarah) — konten statis dipakai laporan RAT otomatis ──
app.MapGet("/api/admin/profil-koperasi", async (KkcsDbContext db) =>
{
    var profil = await db.ProfilKoperasi.AsNoTracking().FirstOrDefaultAsync() ?? new ProfilKoperasi { Id = 1 };
    return Results.Ok(new ProfilKoperasiResponse(profil.Visi, profil.Misi, profil.AlamatKantor, profil.TanggalDidirikan, profil.NomorAktaPendirian, profil.TanggalAkta));
}).RequireAuthorization("Pengurus");

app.MapPut("/api/admin/profil-koperasi", async (ProfilKoperasiRequest request, KkcsDbContext db) =>
{
    var profil = await db.ProfilKoperasi.FirstOrDefaultAsync();
    if (profil is null) { profil = new ProfilKoperasi { Id = 1 }; db.ProfilKoperasi.Add(profil); }
    profil.Visi = request.Visi.Trim();
    profil.Misi = request.Misi.Trim();
    profil.AlamatKantor = string.IsNullOrWhiteSpace(request.AlamatKantor) ? null : request.AlamatKantor.Trim();
    profil.TanggalDidirikan = request.TanggalDidirikan;
    profil.NomorAktaPendirian = string.IsNullOrWhiteSpace(request.NomorAktaPendirian) ? null : request.NomorAktaPendirian.Trim();
    profil.TanggalAkta = request.TanggalAkta;
    profil.DiperbaruiPada = DateTime.UtcNow;
    await db.SaveChangesAsync();
    return Results.Ok(new ProfilKoperasiResponse(profil.Visi, profil.Misi, profil.AlamatKantor, profil.TanggalDidirikan, profil.NomorAktaPendirian, profil.TanggalAkta));
}).RequireAuthorization("Pengurus");

// ── Admin: Laporan RAT otomatis — gabungan data sistem (Neraca/Hasil Usaha/SHU/Keanggotaan) + konten
// manual (narasi kegiatan, rencana tahun depan, target RAB) per tahun buku. ──
app.MapGet("/api/admin/rat/{tahun:int}/konten", async (int tahun, KkcsDbContext db) =>
{
    var konten = await db.RatTahunan.AsNoTracking().FirstOrDefaultAsync(item => item.Tahun == tahun);
    return Results.Ok(ToRatKontenResponse(tahun, konten));
}).RequireAuthorization("Pengurus");

app.MapPut("/api/admin/rat/{tahun:int}/konten", async (int tahun, RatKontenRequest request, KkcsDbContext db) =>
{
    var konten = await db.RatTahunan.FirstOrDefaultAsync(item => item.Tahun == tahun);
    if (konten is null) { konten = new RatTahunan { Tahun = tahun }; db.RatTahunan.Add(konten); }
    konten.KegiatanBisnis = request.KegiatanBisnis;
    konten.KegiatanSosial = request.KegiatanSosial;
    konten.RencanaBisnisTahunDepan = request.RencanaBisnisTahunDepan;
    konten.RencanaSosialTahunDepan = request.RencanaSosialTahunDepan;
    konten.RabPendapatanPinjaman = request.RabPendapatanPinjaman;
    konten.RabPendapatanLain = request.RabPendapatanLain;
    konten.RabBebanOperasional = request.RabBebanOperasional;
    konten.RabBebanUmum = request.RabBebanUmum;
    konten.RabCadanganPiutang = request.RabCadanganPiutang;
    konten.RealisasiPajakShu = request.RealisasiPajakShu;
    konten.CatatanTambahan = request.CatatanTambahan;
    konten.DiperbaruiPada = DateTime.UtcNow;
    await db.SaveChangesAsync();
    return Results.Ok(ToRatKontenResponse(tahun, konten));
}).RequireAuthorization("Pengurus");

app.MapGet("/api/admin/rat/{tahun:int}/laporan", async (int tahun, KkcsDbContext db) =>
    Results.Ok(await BuatLaporanRatAsync(db, tahun)))
    .RequireAuthorization("Pengurus");

app.MapPost("/api/admin/rat/{tahun:int}/publikasikan", async (int tahun, RatPublikasiRequest request, ClaimsPrincipal principal, KkcsDbContext db, AuditService audit) =>
{
    var konten = await db.RatTahunan.FirstOrDefaultAsync(item => item.Tahun == tahun);
    if (request.Publikasikan)
    {
        var laporan = await BuatLaporanRatAsync(db, tahun);
        if (laporan.ItemBelumLengkap.Count > 0)
        {
            return Results.BadRequest(new { message = "Laporan belum lengkap: " + string.Join("; ", laporan.ItemBelumLengkap) });
        }
        if (konten is null) { konten = new RatTahunan { Tahun = tahun }; db.RatTahunan.Add(konten); }
        konten.Dipublikasikan = true;
        konten.DipublikasikanPada = DateTime.UtcNow;
        await db.SaveChangesAsync();
        await audit.CatatAsync(principal, "RAT", "Tayangkan", $"Menayangkan laporan RAT otomatis tahun buku {tahun} ke aplikasi anggota.", tahun);
        return Results.Ok(new { message = $"Laporan RAT tahun {tahun} sudah tayang di aplikasi anggota.", dipublikasikan = true });
    }

    if (konten is null) return Results.Ok(new { message = "Laporan belum pernah ditayangkan.", dipublikasikan = false });
    konten.Dipublikasikan = false;
    konten.DipublikasikanPada = null;
    await db.SaveChangesAsync();
    await audit.CatatAsync(principal, "RAT", "BatalTayang", $"Membatalkan penayangan laporan RAT otomatis tahun buku {tahun}.", tahun);
    return Results.Ok(new { message = $"Laporan RAT tahun {tahun} dibatalkan penayangannya.", dipublikasikan = false });
}).RequireAuthorization("Pengurus");

app.MapGet("/api/anggota", async (KkcsDbContext db) =>
    Results.Ok(await db.Anggota.AsNoTracking().OrderBy(anggota => anggota.NamaLengkap).ToListAsync()))
    .RequireAuthorization();

app.MapGet("/api/anggota/{id:int}", async (int id, KkcsDbContext db) =>
{
    var anggota = await db.Anggota.AsNoTracking().FirstOrDefaultAsync(item => item.Id == id);
    return anggota is null ? Results.NotFound() : Results.Ok(anggota);
}).RequireAuthorization();

app.MapPost("/api/anggota", async (AnggotaRequest request, KkcsDbContext db) =>
{
    if (string.IsNullOrWhiteSpace(request.NomorAnggota) || string.IsNullOrWhiteSpace(request.NamaLengkap))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["anggota"] = ["Nomor anggota dan nama lengkap wajib diisi."]
        });
    }

    var nomorAnggota = request.NomorAnggota.Trim();
    if (await db.Anggota.AnyAsync(anggota => anggota.NomorAnggota == nomorAnggota))
    {
        return Results.Conflict(new { message = "Nomor anggota sudah digunakan." });
    }

    var anggotaBaru = new Anggota
    {
        NomorAnggota = nomorAnggota,
        NamaLengkap = request.NamaLengkap.Trim(),
        NomorIdentitas = request.NomorIdentitas?.Trim(),
        Email = request.Email?.Trim(),
        NomorTelepon = request.NomorTelepon?.Trim(),
        Alamat = request.Alamat?.Trim(),
        TanggalBergabung = request.TanggalBergabung ?? DateTime.UtcNow,
        Aktif = request.Aktif ?? true
    };

    db.Anggota.Add(anggotaBaru);
    await db.SaveChangesAsync();
    return Results.Created($"/api/anggota/{anggotaBaru.Id}", anggotaBaru);
}).RequireAuthorization();

app.MapPut("/api/anggota/{id:int}", async (int id, AnggotaRequest request, KkcsDbContext db) =>
{
    var anggota = await db.Anggota.FirstOrDefaultAsync(item => item.Id == id);
    if (anggota is null)
    {
        return Results.NotFound();
    }

    if (string.IsNullOrWhiteSpace(request.NomorAnggota) || string.IsNullOrWhiteSpace(request.NamaLengkap))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["anggota"] = ["Nomor anggota dan nama lengkap wajib diisi."]
        });
    }

    var nomorAnggota = request.NomorAnggota.Trim();
    if (await db.Anggota.AnyAsync(item => item.Id != id && item.NomorAnggota == nomorAnggota))
    {
        return Results.Conflict(new { message = "Nomor anggota sudah digunakan." });
    }

    anggota.NomorAnggota = nomorAnggota;
    anggota.NamaLengkap = request.NamaLengkap.Trim();
    anggota.NomorIdentitas = request.NomorIdentitas?.Trim();
    anggota.Email = request.Email?.Trim();
    anggota.NomorTelepon = request.NomorTelepon?.Trim();
    anggota.Alamat = request.Alamat?.Trim();
    anggota.TanggalBergabung = request.TanggalBergabung ?? anggota.TanggalBergabung;
    anggota.Aktif = request.Aktif ?? anggota.Aktif;
    await db.SaveChangesAsync();
    return Results.Ok(anggota);
}).RequireAuthorization();

app.MapDelete("/api/anggota/{id:int}", async (int id, KkcsDbContext db) =>
{
    var anggota = await db.Anggota.FindAsync(id);
    if (anggota is null)
    {
        return Results.NotFound();
    }

    db.Anggota.Remove(anggota);
    await db.SaveChangesAsync();
    return Results.NoContent();
}).RequireAuthorization();

var summaries = new[]
{
    "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
};

app.MapGet("/weatherforecast", () =>
{
    var forecast =  Enumerable.Range(1, 5).Select(index =>
        new WeatherForecast
        (
            DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
            Random.Shared.Next(-20, 55),
            summaries[Random.Shared.Next(summaries.Length)]
        ))
        .ToArray();
    return forecast;
})
.WithName("GetWeatherForecast");

app.Run();

static async Task<Pengguna?> FindCurrentUser(ClaimsPrincipal principal, KkcsDbContext db)
{
    var subject = principal.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? principal.FindFirstValue(ClaimTypes.Name)
        ?? principal.FindFirstValue("sub");
    return int.TryParse(subject, out var penggunaId)
        ? await db.Pengguna.FirstOrDefaultAsync(item => item.Id == penggunaId && item.Aktif)
        : null;
}

// Anggota yang pendaftarannya sudah disetujui pengurus. null bila belum aktif.
static async Task<Pengguna?> FindActiveMember(ClaimsPrincipal principal, KkcsDbContext db)
{
    var pengguna = await FindCurrentUser(principal, db);
    return pengguna is { StatusKeanggotaan: "Aktif" } ? pengguna : null;
}

static async Task<string?> SimpanFotoAsync(IFormFile file, IWebHostEnvironment environment, string subfolder)
{
    if (file.Length == 0 || file.Length > 5 * 1024 * 1024) return null;
    var allowed = new[] { ".jpg", ".jpeg", ".png", ".webp" };
    var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
    if (!allowed.Contains(ext) || !file.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase)) return null;

    var webRoot = environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot");
    var dir = Path.Combine(webRoot, "uploads", subfolder);
    Directory.CreateDirectory(dir);
    var name = $"{Guid.NewGuid():N}{ext}";
    await using var stream = File.Create(Path.Combine(dir, name));
    await file.CopyToAsync(stream);
    return $"/uploads/{subfolder}/{name}";
}

static async Task<string?> SimpanDokumenAsync(IFormFile file, IWebHostEnvironment environment, string subfolder)
{
    if (file.Length == 0 || file.Length > 20 * 1024 * 1024) return null;
    var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
    if (ext != ".pdf") return null;

    var webRoot = environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot");
    var dir = Path.Combine(webRoot, "uploads", subfolder);
    Directory.CreateDirectory(dir);
    var name = $"{Guid.NewGuid():N}{ext}";
    await using var stream = File.Create(Path.Combine(dir, name));
    await file.CopyToAsync(stream);
    return $"/uploads/{subfolder}/{name}";
}

static async Task<string?> SimpanBuktiAsync(IFormFile file, IWebHostEnvironment environment, string subfolder)
{
    if (file.Length == 0 || file.Length > 10 * 1024 * 1024) return null;
    var allowed = new[] { ".jpg", ".jpeg", ".png", ".pdf" };
    var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
    if (!allowed.Contains(ext)) return null;
    var contentTypeOk = file.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase) || file.ContentType == "application/pdf";
    if (!contentTypeOk) return null;

    var webRoot = environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot");
    var dir = Path.Combine(webRoot, "uploads", subfolder);
    Directory.CreateDirectory(dir);
    var name = $"{Guid.NewGuid():N}{ext}";
    await using var stream = File.Create(Path.Combine(dir, name));
    await file.CopyToAsync(stream);
    return $"/uploads/{subfolder}/{name}";
}

static void HapusFoto(string? fotoUrl, IWebHostEnvironment environment)
{
    if (string.IsNullOrWhiteSpace(fotoUrl)) return;
    var webRoot = environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot");
    var path = Path.Combine(webRoot, fotoUrl.TrimStart('/').Replace('/', Path.DirectorySeparatorChar));
    if (File.Exists(path)) File.Delete(path);
}

static EratAgendaResponse ToEratAgendaResponse(EratAgenda agenda, int pilihanSaya)
{
    var opsi = agenda.Opsi.OrderBy(o => o.Urutan).ThenBy(o => o.Id)
        .Select(o => new EratOpsiResponse(o.Id, o.Label, o.Suara?.Count ?? 0))
        .ToList();
    return new EratAgendaResponse(
        agenda.Id, agenda.Judul, agenda.Deskripsi, agenda.Status,
        agenda.MulaiPada, agenda.SelesaiPada, agenda.DibuatPada,
        opsi.Sum(o => o.Jumlah), pilihanSaya == 0 ? null : pilihanSaya, opsi);
}

static RatKontenResponse ToRatKontenResponse(int tahun, RatTahunan? konten) => new(
    tahun,
    konten?.KegiatanBisnis, konten?.KegiatanSosial,
    konten?.RencanaBisnisTahunDepan, konten?.RencanaSosialTahunDepan,
    konten?.RabPendapatanPinjaman, konten?.RabPendapatanLain,
    konten?.RabBebanOperasional, konten?.RabBebanUmum, konten?.RabCadanganPiutang,
    konten?.RealisasiPajakShu, konten?.CatatanTambahan,
    konten?.Dipublikasikan ?? false, konten?.DipublikasikanPada);

static List<string> CekKelengkapanRat(RatTahunan? konten, RatShuResponse? shu)
{
    var kurang = new List<string>();
    if (konten is null || string.IsNullOrWhiteSpace(konten.KegiatanBisnis)) kurang.Add("Kegiatan Bisnis tahun berjalan belum diisi");
    if (konten is null || string.IsNullOrWhiteSpace(konten.KegiatanSosial)) kurang.Add("Kegiatan Sosial tahun berjalan belum diisi");
    if (konten is null || string.IsNullOrWhiteSpace(konten.RencanaBisnisTahunDepan)) kurang.Add("Rencana Kegiatan Bisnis tahun depan belum diisi");
    if (konten is null || string.IsNullOrWhiteSpace(konten.RencanaSosialTahunDepan)) kurang.Add("Rencana Kegiatan Sosial tahun depan belum diisi");
    if (konten?.RealisasiPajakShu is null) kurang.Add("Realisasi Pajak SHU belum diisi");
    if (shu is null) kurang.Add("SHU tahun buku ini belum difinalisasi di menu Akuntansi → tab SHU");
    return kurang;
}

static async Task<LaporanRatResponse> BuatLaporanRatAsync(KkcsDbContext db, int tahun)
{
    var akhirTahun = new DateTime(tahun, 12, 31, 23, 59, 59, 999);
    var awalTahun = new DateTime(tahun, 1, 1);
    var akhirTahunLalu = awalTahun.AddDays(-1);

    var profil = await db.ProfilKoperasi.AsNoTracking().FirstOrDefaultAsync() ?? new ProfilKoperasi { Id = 1 };
    var konten = await db.RatTahunan.AsNoTracking().FirstOrDefaultAsync(item => item.Tahun == tahun);

    var neracaAkhirTahun = await AkuntansiReportService.HitungNeracaAsync(db, akhirTahun);
    var neracaTahunLalu = tahun > 2000 ? await AkuntansiReportService.HitungNeracaAsync(db, akhirTahunLalu) : null;
    var labaRugi = await AkuntansiReportService.HitungLabaRugiAsync(db, awalTahun, akhirTahun);
    var bukuBesar = await AkuntansiReportService.HitungBukuBesarTahunanAsync(db, tahun);

    var shu = await db.ShuRun.AsNoTracking().Where(item => item.Tahun == tahun)
        .Select(item => new RatShuResponse(
            item.TotalShu, item.TotalPajak, item.TotalShuNeto,
            item.PersenAnggota, item.PersenJasaModal, item.PersenJasaUsaha, item.PersenPengurus, item.PersenCadangan,
            item.JasaPengurusPool, item.CadanganAmount, item.Rincian.Count, item.DifinalisasiPada))
        .FirstOrDefaultAsync();

    var totalAnggotaAktifSaatIni = await db.Pengguna.CountAsync(p => p.StatusKeanggotaan == "Aktif" && p.Aktif);
    var anggotaBaruTahunIni = await db.Pengguna.CountAsync(p => p.DisetujuiPada != null && p.DisetujuiPada >= awalTahun && p.DisetujuiPada <= akhirTahun);
    var totalAnggotaNonaktifSaatIni = await db.Pengguna.CountAsync(p => !p.Aktif || p.StatusKeanggotaan != "Aktif");

    var rabTotalPendapatan = (konten?.RabPendapatanPinjaman ?? 0) + (konten?.RabPendapatanLain ?? 0);
    var rabTotalBebanRaw = (konten?.RabBebanOperasional ?? 0) + (konten?.RabBebanUmum ?? 0) + (konten?.RabCadanganPiutang ?? 0);

    // Realisasi beban dipetakan ke 3 kategori RAB dari RAT: akun 5-5910 (Beban Umum & Administrasi) dan
    // 5-5920 (Beban Penyisihan Piutang Tak Tertagih) dipisah sendiri; sisanya (bunga simpanan, HPP
    // produk, gaji/sewa, dll) dianggap Beban Operasional — biaya inti menjalankan koperasi sehari-hari.
    var realisasiBebanUmum = labaRugi.Beban.Where(b => b.Kode == "5-5910").Sum(b => b.Saldo);
    var realisasiBebanCadanganPiutang = labaRugi.Beban.Where(b => b.Kode == "5-5920").Sum(b => b.Saldo);
    var realisasiBebanOperasional = labaRugi.TotalBeban - realisasiBebanUmum - realisasiBebanCadanganPiutang;

    var shuSebelumPajak = labaRugi.LabaBersih;
    var pajakShu = konten?.RealisasiPajakShu;
    var shuSetelahPajak = pajakShu.HasValue ? shuSebelumPajak - pajakShu.Value : (decimal?)null;

    return new LaporanRatResponse(
        tahun,
        new ProfilKoperasiResponse(profil.Visi, profil.Misi, profil.AlamatKantor, profil.TanggalDidirikan, profil.NomorAktaPendirian, profil.TanggalAkta),
        ToRatKontenResponse(tahun, konten),
        totalAnggotaAktifSaatIni, anggotaBaruTahunIni, totalAnggotaNonaktifSaatIni,
        neracaAkhirTahun, neracaTahunLalu,
        labaRugi, bukuBesar, shu,
        shuSebelumPajak, pajakShu, shuSetelahPajak,
        konten == null || rabTotalPendapatan == 0 ? null : rabTotalPendapatan,
        konten == null || rabTotalBebanRaw == 0 ? null : rabTotalBebanRaw,
        realisasiBebanOperasional, realisasiBebanUmum, realisasiBebanCadanganPiutang,
        CekKelengkapanRat(konten, shu));
}

static ProdukResponse ToProdukResponse(Produk item) => new(
    item.Id, item.Kode, item.Nama, item.Deskripsi, item.Jenis, item.Harga, item.Stok, item.Satuan,
    item.FotoUrl, item.Sumber, item.DiajukanOleh?.NamaLengkap, item.Status, item.Aktif, item.CatatanReview);

static string BuatPasswordSementara()
{
    const string karakter = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789"; // tanpa 0/O/1/l/I yang mirip
    return new string(Enumerable.Range(0, 10).Select(_ => karakter[Random.Shared.Next(karakter.Length)]).ToArray());
}

static IResult BelumAktif() =>
    Results.Json(new { message = "Akun Anda belum aktif. Menunggu persetujuan pengurus koperasi." }, statusCode: StatusCodes.Status403Forbidden);

static UserResponse ToUserResponse(Pengguna pengguna) => new(
    pengguna.Id,
    pengguna.NamaLengkap,
    pengguna.NomorIndukKaryawan,
    pengguna.Peran,
    pengguna.StatusKeanggotaan,
    pengguna.Email,
    pengguna.NomorTelepon,
    pengguna.Alamat,
    pengguna.FotoUrl);

static PengajuanResponse ToPengajuanResponse(PengajuanPinjaman item) => new(
    item.Id, item.NomorPengajuan, item.Nominal, item.TenorBulan, item.BungaTahunan,
    item.EstimasiCicilanBulanan, item.EstimasiTotalJasa, item.Tujuan, item.Status,
    item.CatatanReview, item.DibuatPada, item.DiputuskanPada, item.SuratRekomendasiUrl);

static SukarelaRutinResponse ToSukarelaRutinResponse(SukarelaRutin item) => new(
    item.Id, item.Nominal, item.TanggalSetor, item.Status, item.CatatanReview,
    item.DiajukanPada, item.DiputuskanPada, item.TerakhirDijalankanPeriode);

static async Task<AnggotaDetailResponse?> BuatAnggotaDetailAsync(int id, KkcsDbContext db)
{
    var pengguna = await db.Pengguna.AsNoTracking().FirstOrDefaultAsync(item => item.Id == id);
    if (pengguna is null) return null;

    var simpanan = await db.Simpanan.AsNoTracking().Include(item => item.JenisSimpanan)
        .Where(item => item.PenggunaId == id).ToListAsync();
    decimal SaldoJenis(string kode) => simpanan.FirstOrDefault(item => item.JenisSimpanan.Kode == kode)?.Saldo ?? 0;

    var berjangka = await db.SimpananBerjangka.AsNoTracking().Include(item => item.Produk)
        .Where(item => item.PenggunaId == id)
        .OrderByDescending(item => item.DiajukanPada)
        .Select(item => new BerjangkaRingkasResponse(item.NomorSertifikat, item.Produk.Nama, item.Nominal, item.TenorBulan, item.Status, item.TanggalMulai, item.TanggalJatuhTempo))
        .ToListAsync();

    var pinjaman = await db.Pinjaman.AsNoTracking()
        .Where(item => item.PenggunaId == id)
        .OrderByDescending(item => item.DibuatPada)
        .Select(item => new PinjamanRingkasResponse(item.NomorPinjaman, item.Pokok, item.TenorBulan, item.AngsuranPerBulan, item.SisaPokok, item.AngsuranTerbayar, item.Status, item.TanggalMulai, item.LunasPada))
        .ToListAsync();

    var belanja = await db.PembelianProduk.AsNoTracking().Include(item => item.Produk)
        .Where(item => item.PembeliId == id)
        .OrderByDescending(item => item.DiajukanPada)
        .Select(item => new BelanjaRingkasResponse(item.NomorTransaksi, item.Produk.Nama, item.Jenis, item.Jumlah, item.Total, item.MetodePembayaran, item.Status, item.DiajukanPada))
        .ToListAsync();

    var totalTagihanKreditBelum = await db.TagihanKredit.AsNoTracking()
        .Where(item => item.PenggunaId == id && item.Status != "Lunas")
        .SumAsync(item => item.Total);

    var berjangkaAktif = berjangka.Where(item => item.Status is "Aktif" or "JatuhTempo").Sum(item => item.Nominal);
    var totalSimpanan = SaldoJenis("POKOK") + SaldoJenis("WAJIB") + SaldoJenis("SUKARELA") + berjangkaAktif;

    var simpananIds = simpanan.Select(item => item.Id).ToList();
    var namaJenisById = simpanan.ToDictionary(item => item.Id, item => item.JenisSimpanan.Nama);
    var riwayat = await db.MutasiSimpanan.AsNoTracking()
        .Where(item => simpananIds.Contains(item.SimpananId))
        .OrderByDescending(item => item.TanggalTransaksi).ThenByDescending(item => item.Id)
        .Take(30)
        .Select(item => new { item.SimpananId, item.Jenis, item.Nominal, item.SaldoSetelah, item.Keterangan, item.TanggalTransaksi })
        .ToListAsync();

    return new AnggotaDetailResponse(
        pengguna.Id, pengguna.NamaLengkap, pengguna.NomorIndukKaryawan, pengguna.Email, pengguna.NomorTelepon, pengguna.Alamat,
        pengguna.Peran, pengguna.StatusKeanggotaan, pengguna.Aktif, pengguna.DibuatPada, pengguna.DisetujuiPada,
        SaldoJenis("POKOK"), SaldoJenis("WAJIB"), SaldoJenis("SUKARELA"), berjangkaAktif, totalSimpanan,
        berjangka, pinjaman, belanja, totalTagihanKreditBelum,
        riwayat.Select(item => new RiwayatSimpananResponse(
            namaJenisById.GetValueOrDefault(item.SimpananId, "—"), item.Jenis, item.Nominal, item.SaldoSetelah, item.Keterangan, item.TanggalTransaksi)).ToList());
}

static List<AngsuranResponse> ToAngsuranResponses(Pinjaman pinjaman) => pinjaman.Angsuran
    .OrderBy(item => item.AngsuranKe)
    .Select(item => new AngsuranResponse(
        item.AngsuranKe, item.JatuhTempo, item.Pokok, item.Jasa, item.Total,
        item.Jenis, item.Status, item.JumlahDibayar, item.DibayarPada))
    .ToList();

static PinjamanResponse ToPinjamanResponse(Pinjaman pinjaman, PembayaranPinjaman? tertunda = null)
{
    // Pelunasan dipercepat = sisa pokok saja; jasa bulan yang belum jatuh tempo dibebaskan.
    var jasaDibebaskan = pinjaman.Angsuran
        .Where(item => item.Status == "Belum" && item.Jenis == "Reguler")
        .Sum(item => item.Jasa);
    var sisaAngsuran = pinjaman.Angsuran.Count(item => item.Status == "Belum" && item.Jenis == "Reguler");

    return new PinjamanResponse(
        pinjaman.Id, pinjaman.NomorPinjaman, pinjaman.Pokok, pinjaman.TenorBulan, pinjaman.BungaTahunan,
        pinjaman.PokokPerBulan, pinjaman.JasaPerBulan, pinjaman.AngsuranPerBulan,
        pinjaman.SisaPokok, pinjaman.AngsuranTerbayar, sisaAngsuran,
        pinjaman.TanggalMulai, pinjaman.Status, pinjaman.LunasPada,
        pinjaman.SisaPokok, jasaDibebaskan,
        tertunda is null ? null : new PembayaranTertundaResponse(tertunda.Jenis, tertunda.JumlahDiajukan, tertunda.DiajukanPada),
        ToAngsuranResponses(pinjaman));
}

static AdminPinjamanResponse ToAdminPinjamanResponse(Pinjaman pinjaman)
{
    var jasaDibebaskan = pinjaman.Angsuran
        .Where(item => item.Status == "Belum" && item.Jenis == "Reguler")
        .Sum(item => item.Jasa);
    return new AdminPinjamanResponse(
        pinjaman.Id, pinjaman.NomorPinjaman, pinjaman.Pengguna?.NamaLengkap ?? string.Empty,
        pinjaman.Pengguna?.NomorIndukKaryawan ?? string.Empty,
        pinjaman.Pokok, pinjaman.TenorBulan, pinjaman.BungaTahunan,
        pinjaman.PokokPerBulan, pinjaman.JasaPerBulan, pinjaman.AngsuranPerBulan,
        pinjaman.SisaPokok, pinjaman.AngsuranTerbayar, pinjaman.TanggalMulai,
        pinjaman.Status, pinjaman.LunasPada, pinjaman.SisaPokok, jasaDibebaskan,
        ToAngsuranResponses(pinjaman));
}

static JurnalResponse ToJurnalResponse(JurnalEntri item) => new(
    item.Id, item.NomorJurnal, item.Tanggal, item.Keterangan, item.Sumber, item.ReferensiModul, item.ReferensiId,
    item.DicatatOleh?.NamaLengkap,
    item.Baris.Select(b => new JurnalBarisResponse(b.AkunId, b.Akun.Kode, b.Akun.Nama, b.Debit, b.Kredit)).ToList());

static async Task<PayrollRekapResponse> BuatRekapPayroll(KkcsDbContext db, string? periode)
{
    var p = string.IsNullOrWhiteSpace(periode) ? DateTime.Now.ToString("yyyy-MM") : periode.Trim();

    var wajib = await db.TagihanWajib.AsNoTracking()
        .Where(item => item.Periode == p && item.Status == "Ditagih")
        .ToListAsync();
    var kredit = await db.TagihanKredit.AsNoTracking().Include(item => item.Pembelian).ThenInclude(pb => pb.Produk)
        .Where(item => item.Status == "Belum")
        .ToListAsync();
    // Cicilan pinjaman reguler yang jatuh tempo bulan ini dan belum dibayar — ikut dipotong lewat payroll,
    // sama seperti Simpanan Wajib & Tagihan Kredit (anggota bayar lewat potong gaji, bukan setor manual).
    var periodeValid = DateTime.TryParseExact(p, "yyyy-MM", null, System.Globalization.DateTimeStyles.None, out var periodeAwal);
    var periodeAkhir = periodeAwal.AddMonths(1);
    var angsuran = periodeValid
        ? await db.AngsuranPinjaman.AsNoTracking().Include(item => item.Pinjaman)
            .Where(item => item.Status == "Belum" && item.Jenis == "Reguler" && item.Pinjaman.Status == "Aktif"
                && item.JatuhTempo >= periodeAwal && item.JatuhTempo < periodeAkhir)
            .ToListAsync()
        : [];

    // Sukarela Rutin aktif — nominal setoran otomatis bulanan, ikut ditampilkan sebagai potongan gaji informatif.
    var sukarelaRutin = await db.SukarelaRutin.AsNoTracking()
        .Where(item => item.Status == "Aktif")
        .ToListAsync();

    var wajibPerAnggota = wajib.GroupBy(item => item.PenggunaId).ToDictionary(g => g.Key, g => g.Sum(x => x.Nominal));
    var kreditPerAnggota = kredit.GroupBy(item => item.PenggunaId).ToDictionary(g => g.Key, g => g.Sum(x => x.Total));
    var pinjamanPerAnggota = angsuran.GroupBy(item => item.Pinjaman.PenggunaId).ToDictionary(g => g.Key, g => g.Sum(x => x.Total));
    var sukarelaRutinPerAnggota = sukarelaRutin.GroupBy(item => item.PenggunaId).ToDictionary(g => g.Key, g => g.Sum(x => x.Nominal));
    var semuaId = wajibPerAnggota.Keys.Union(kreditPerAnggota.Keys).Union(pinjamanPerAnggota.Keys).Union(sukarelaRutinPerAnggota.Keys).ToList();

    var pengguna = await db.Pengguna.AsNoTracking().Where(item => semuaId.Contains(item.Id)).ToListAsync();
    var baris = pengguna.Select(item =>
    {
        var w = wajibPerAnggota.GetValueOrDefault(item.Id, 0m);
        var k = kreditPerAnggota.GetValueOrDefault(item.Id, 0m);
        var c = pinjamanPerAnggota.GetValueOrDefault(item.Id, 0m);
        var sr = sukarelaRutinPerAnggota.GetValueOrDefault(item.Id, 0m);
        var items = new List<PayrollItemResponse>();
        items.AddRange(wajib.Where(x => x.PenggunaId == item.Id)
            .Select(x => new PayrollItemResponse("Wajib", x.Id, $"Simpanan Wajib periode {x.Periode}", x.Nominal)));
        items.AddRange(kredit.Where(x => x.PenggunaId == item.Id)
            .Select(x => new PayrollItemResponse("Kredit", x.Id, $"Kredit: {x.Pembelian.Produk.Nama} ({x.Pembelian.NomorTransaksi})", x.Total)));
        items.AddRange(angsuran.Where(x => x.Pinjaman.PenggunaId == item.Id)
            .Select(x => new PayrollItemResponse("Cicilan", x.Id, $"Angsuran ke-{x.AngsuranKe} pinjaman {x.Pinjaman.NomorPinjaman}", x.Total)));
        items.AddRange(sukarelaRutin.Where(x => x.PenggunaId == item.Id)
            .Select(x => new PayrollItemResponse("SukarelaRutin", x.Id, $"Sukarela Rutin (otomatis, tanggal {x.TanggalSetor})", x.Nominal)));
        return new PayrollBarisResponse(item.Id, item.NamaLengkap, item.NomorIndukKaryawan, w, k, c, sr, w + k + c + sr, items);
    }).OrderByDescending(item => item.TotalPotongan).ToList();

    return new PayrollRekapResponse(p, baris, baris.Sum(item => item.SimpananWajib), baris.Sum(item => item.TagihanKredit), baris.Sum(item => item.CicilanPinjaman), baris.Sum(item => item.SukarelaRutin), baris.Sum(item => item.TotalPotongan));
}

static KonfigurasiResponse ToKonfigurasiResponse(KonfigurasiKoperasi item) => new(
    item.SimpananPokokNominal, item.SimpananWajibNominal, item.TanggalTagihWajib,
    item.BungaSukarelaTahunan, item.BungaDepositoTahunan, item.TarifPph, item.TarifPphShu, item.DiperbaruiPada);

static BerjangkaResponse ToBerjangkaResponse(SimpananBerjangka item, decimal bungaDepositoTahunan) => new(
    item.Id, item.NomorSertifikat, item.Produk?.Nama ?? string.Empty, item.Nominal, item.TenorBulan,
    item.Status, item.CatatanReview, item.DiajukanPada, item.TanggalMulai, item.TanggalJatuhTempo, item.DicairkanPada,
    item.BungaDibayar ?? BungaDeposito.Hitung(item.Nominal, bungaDepositoTahunan, item.TenorBulan),
    item.BungaDibayar,
    item.PencairanDiajukan, item.PencairanDiajukanPada, item.BuktiTransferUrl);

record WeatherForecast(DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}

record NeracaAwalBarisInput(string KodeAkun, decimal Debit, decimal Kredit);
record NeracaAwalKomitRequest(DateTime Tanggal, string Keterangan, List<NeracaAwalBarisInput> Baris, string? Signature = null);

record SimpananMigrasiBarisInput(int PenggunaId, decimal SaldoPokok, decimal SaldoWajib);
record SimpananMigrasiKomitRequest(DateTime Tanggal, List<SimpananMigrasiBarisInput> Baris, string? Signature = null);

record PinjamanMigrasiBarisInput(int PenggunaId, decimal Nominal, int TenorBulan, DateTime TanggalMulai, int AngsuranSudahDibayar, decimal? SisaPokokOverride);
record PinjamanMigrasiKomitRequest(DateTime Tanggal, List<PinjamanMigrasiBarisInput> Baris, string? Signature = null);

record TagihanKreditMigrasiBarisInput(int PenggunaId, string Keterangan, decimal Total, int TenorBulan, DateTime TanggalMulai, int AngsuranSudahDibayar, decimal? SisaPokokOverride);
record TagihanKreditMigrasiKomitRequest(DateTime Tanggal, List<TagihanKreditMigrasiBarisInput> Baris, string? Signature = null);

record JurnalHarianBarisInput(string KodeAkun, decimal Debit, decimal Kredit, int? PenggunaId, string? EfekSaldo);
record JurnalHarianVoucherInput(string NoBukti, DateTime Tanggal, string Keterangan, List<JurnalHarianBarisInput> Baris);
record JurnalHarianKomitRequest(List<JurnalHarianVoucherInput> Voucher, string? Signature = null);

record AnggotaRequest(
    string NomorAnggota,
    string NamaLengkap,
    string? NomorIdentitas,
    string? Email,
    string? NomorTelepon,
    string? Alamat,
    DateTime? TanggalBergabung,
    bool? Aktif);

record RegisterRequest(string NamaLengkap, string NomorIndukKaryawan, string? Email, string Password);

record LoginRequest(string NomorIndukKaryawan, string Password);

record UserResponse(
    int Id,
    string NamaLengkap,
    string NomorIndukKaryawan,
    string Peran,
    string StatusKeanggotaan,
    string? Email,
    string? NomorTelepon,
    string? Alamat,
    string? FotoUrl);

record AuthResponse(string Token, UserResponse User);

record ProfileRequest(string NamaLengkap, string? Email, string? NomorTelepon, string? Alamat);

// ── Laporan RAT otomatis ──────────────────────────────────────────────────────
record ProfilKoperasiResponse(string Visi, string Misi, string? AlamatKantor, DateTime? TanggalDidirikan, string? NomorAktaPendirian, DateTime? TanggalAkta);
record ProfilKoperasiRequest(string Visi, string Misi, string? AlamatKantor, DateTime? TanggalDidirikan, string? NomorAktaPendirian, DateTime? TanggalAkta);
record RatKontenResponse(
    int Tahun, string? KegiatanBisnis, string? KegiatanSosial,
    string? RencanaBisnisTahunDepan, string? RencanaSosialTahunDepan,
    decimal? RabPendapatanPinjaman, decimal? RabPendapatanLain,
    decimal? RabBebanOperasional, decimal? RabBebanUmum, decimal? RabCadanganPiutang,
    decimal? RealisasiPajakShu, string? CatatanTambahan,
    bool Dipublikasikan, DateTime? DipublikasikanPada);
record RatPublikasiRequest(bool Publikasikan);
record RatKontenRequest(
    string? KegiatanBisnis, string? KegiatanSosial,
    string? RencanaBisnisTahunDepan, string? RencanaSosialTahunDepan,
    decimal? RabPendapatanPinjaman, decimal? RabPendapatanLain,
    decimal? RabBebanOperasional, decimal? RabBebanUmum, decimal? RabCadanganPiutang,
    decimal? RealisasiPajakShu, string? CatatanTambahan);
record RatShuResponse(
    decimal TotalShu, decimal TotalPajak, decimal TotalShuNeto,
    decimal PersenAnggota, decimal PersenJasaModal, decimal PersenJasaUsaha, decimal PersenPengurus, decimal PersenCadangan,
    decimal JasaPengurusPool, decimal CadanganAmount, int JumlahAnggota, DateTime DifinalisasiPada);
record LaporanRatResponse(
    int Tahun,
    ProfilKoperasiResponse Profil,
    RatKontenResponse Konten,
    int TotalAnggotaAktifSaatIni, int AnggotaBaruTahunIni, int TotalAnggotaNonaktifSaatIni,
    NeracaResult NeracaAkhirTahun, NeracaResult? NeracaTahunLalu,
    LabaRugiResult LabaRugi, List<BukuBesarAkunItem> BukuBesar, RatShuResponse? Shu,
    decimal ShuSebelumPajak, decimal? PajakShu, decimal? ShuSetelahPajak,
    decimal? RabTotalPendapatan, decimal? RabTotalBeban,
    decimal RealisasiBebanOperasional, decimal RealisasiBebanUmum, decimal RealisasiBebanCadanganPiutang,
    List<string> ItemBelumLengkap);
record GantiPasswordRequest(string PasswordLama, string PasswordBaru);

record DashboardTrenBulanan(string Label, decimal Pendapatan, decimal Beban, decimal LabaBersih);
record DashboardShuTerakhir(int Tahun, decimal TotalShu, decimal TotalShuNeto, int JumlahAnggota, DateTime DifinalisasiPada);
record DashboardAktivitas(DateTime WaktuUtc, string PelakuNama, string Modul, string Aksi, string Ringkasan);
record DashboardRingkasanResponse(
    int TotalAnggotaAktif, int PendaftaranMenunggu,
    decimal TotalSimpanan, decimal SaldoPokok, decimal SaldoWajib, decimal SaldoSukarela, decimal SaldoBerjangka,
    int WajibMenunggu, int SukarelaMenunggu, int BerjangkaMenunggu,
    int PinjamanAktifCount, decimal TotalSisaPokokPinjaman, int PengajuanPinjamanMenunggu, int PembayaranPinjamanMenunggu,
    int TitipanMenunggu, int PembelianMenunggu, decimal TagihanKreditBelumLunas,
    decimal TotalAset, decimal TotalLiabilitas, decimal TotalEkuitas, decimal SelisihNeraca,
    decimal PendapatanTahunIni, decimal BebanTahunIni, decimal LabaBersihTahunIni,
    decimal LabaBersihBulanIni,
    List<DashboardTrenBulanan> TrenBulanan, DashboardShuTerakhir? ShuTerakhir,
    decimal PayrollTotalPeriodeIni, int PayrollJumlahAnggota,
    int AuditHariIni, List<DashboardAktivitas> AktivitasTerbaru,
    int TotalMenunggu);
record ArusKasItemResponse(DateTime Tanggal, string Kategori, string Keterangan, string Arah, decimal Nominal);
record ArusKasSayaResponse(decimal TotalMasuk, decimal TotalKeluar, decimal SaldoBersih, List<ArusKasItemResponse> Riwayat);

record PengajuanPinjamanRequest(decimal Nominal, int TenorBulan, string Tujuan);

record EratVoteRequest(int OpsiId);

// ── E-RAT ───────────────────────────────────────────────────────────────────
record EratOpsiResponse(int Id, string Label, int Jumlah);
record EratAgendaResponse(
    int Id, string Judul, string? Deskripsi, string Status,
    DateTime? MulaiPada, DateTime? SelesaiPada, DateTime DibuatPada,
    int TotalSuara, int? PilihanSaya, List<EratOpsiResponse> Opsi);
record EratAgendaRequest(string Judul, string? Deskripsi, List<string?>? Opsi, DateTime? MulaiPada, DateTime? SelesaiPada);
record EratOpsiRequest(string Label);
record EratStatusRequest(string Status);
record LaporanResponse(int Id, int Tahun, string Judul, string? Deskripsi, string FileUrl, DateTime DiterbitkanPada);
record AdminLaporanResponse(int Id, int Tahun, string Judul, string? Deskripsi, string FileUrl, DateTime DiterbitkanPada, bool Aktif);

record TarifPinjamanResponse(int TenorBulan, decimal BungaTahunan);

record SimulasiPinjamanResponse(
    decimal Nominal,
    int TenorBulan,
    decimal BungaTahunan,
    decimal PokokPerBulan,
    decimal JasaPerBulan,
    decimal AngsuranPerBulan,
    decimal TotalJasa,
    decimal TotalPembayaran);

record PengajuanResponse(
    int Id,
    string NomorPengajuan,
    decimal Nominal,
    int TenorBulan,
    decimal BungaTahunan,
    decimal EstimasiCicilanBulanan,
    decimal EstimasiTotalJasa,
    string Tujuan,
    string Status,
    string? CatatanReview,
    DateTime DibuatPada,
    DateTime? DiputuskanPada,
    string? SuratRekomendasiUrl);

record AngsuranResponse(
    int AngsuranKe,
    DateTime JatuhTempo,
    decimal Pokok,
    decimal Jasa,
    decimal Total,
    string Jenis,
    string Status,
    decimal? JumlahDibayar,
    DateTime? DibayarPada);

record PinjamanResponse(
    int Id,
    string NomorPinjaman,
    decimal Pokok,
    int TenorBulan,
    decimal BungaTahunan,
    decimal PokokPerBulan,
    decimal JasaPerBulan,
    decimal AngsuranPerBulan,
    decimal SisaPokok,
    int AngsuranTerbayar,
    int SisaAngsuran,
    DateTime TanggalMulai,
    string Status,
    DateTime? LunasPada,
    decimal NilaiPelunasanDipercepat,
    decimal JasaDibebaskan,
    PembayaranTertundaResponse? PembayaranTertunda,
    List<AngsuranResponse> Angsuran);

record PembayaranTertundaResponse(string Jenis, decimal JumlahDiajukan, DateTime DiajukanPada);

record PinjamanSayaResponse(
    List<PengajuanResponse> Pengajuan,
    List<PinjamanResponse> Pinjaman);


record PutusanPembayaranRequest(bool Setuju, string? Catatan);

record AdminPembayaranResponse(
    int Id,
    int PinjamanId,
    string NomorPinjaman,
    string NamaAnggota,
    string NomorIndukKaryawan,
    string Jenis,
    decimal JumlahDiajukan,
    decimal? JasaDibebaskan,
    int? AngsuranKe,
    string? Catatan,
    string Status,
    string? CatatanReview,
    DateTime DiajukanPada,
    DateTime? DiputuskanPada,
    string? BuktiTransferUrl);

record AdminPengajuanResponse(
    int Id,
    string NomorPengajuan,
    string NamaAnggota,
    string NomorIndukKaryawan,
    decimal Nominal,
    int TenorBulan,
    decimal BungaTahunan,
    decimal EstimasiCicilanBulanan,
    decimal EstimasiTotalJasa,
    string Tujuan,
    string Status,
    string? CatatanReview,
    DateTime DibuatPada,
    DateTime? DiputuskanPada,
    string? SuratRekomendasiUrl);

record AdminPinjamanResponse(
    int Id,
    string NomorPinjaman,
    string NamaAnggota,
    string NomorIndukKaryawan,
    decimal Pokok,
    int TenorBulan,
    decimal BungaTahunan,
    decimal PokokPerBulan,
    decimal JasaPerBulan,
    decimal AngsuranPerBulan,
    decimal SisaPokok,
    int AngsuranTerbayar,
    DateTime TanggalMulai,
    string Status,
    DateTime? LunasPada,
    decimal NilaiPelunasanDipercepat,
    decimal JasaDibebaskan,
    List<AngsuranResponse> Angsuran);

record PutusanPengajuanRequest(bool Setuju, string? Catatan, DateTime? TanggalMulai);

// ── Simpanan ────────────────────────────────────────────────────────────────
record KonfigurasiResponse(decimal SimpananPokokNominal, decimal SimpananWajibNominal, int TanggalTagihWajib, decimal BungaSukarelaTahunan, decimal BungaDepositoTahunan, decimal TarifPph, decimal TarifPphShu, DateTime DiperbaruiPada);
record KonfigurasiRequest(decimal SimpananPokokNominal, decimal SimpananWajibNominal, decimal BungaSukarelaTahunan, decimal BungaDepositoTahunan, decimal TarifPph, decimal TarifPphShu);

record PendaftaranResponse(int Id, string NamaLengkap, string NomorIndukKaryawan, string? Email, string StatusKeanggotaan, DateTime DibuatPada);

record ProdukBerjangkaRequest(string Nama, decimal Nominal, int TenorBulan);

record MutasiResponse(string Rekening, string Jenis, decimal Nominal, decimal SaldoSetelah, string? Keterangan, DateTime Tanggal);
record TagihanWajibResponse(int Id, string Periode, decimal Nominal, DateTime JatuhTempo, string Status, string? CatatanReview, DateTime? DiprosesPada);
record TransaksiSukarelaResponse(int Id, string Jenis, decimal Nominal, string? Catatan, string Status, string? CatatanReview, DateTime DiajukanPada, DateTime? DiprosesPada, string? BuktiTransferUrl);
record SukarelaRutinRequest(decimal Nominal, int TanggalSetor);
record SukarelaRutinResponse(int Id, decimal Nominal, int TanggalSetor, string Status, string? CatatanReview, DateTime DiajukanPada, DateTime? DiputuskanPada, string? TerakhirDijalankanPeriode);
record AdminSukarelaRutinResponse(int Id, string NamaAnggota, string NomorIndukKaryawan, decimal Nominal, int TanggalSetor, string Status, string? CatatanReview, DateTime DiajukanPada, DateTime? DiputuskanPada, string? TerakhirDijalankanPeriode);
record ProdukBerjangkaResponse(int Id, string Nama, decimal Nominal, int TenorBulan, bool Aktif);
record BerjangkaResponse(int Id, string NomorSertifikat, string ProdukNama, decimal Nominal, int TenorBulan, string Status, string? CatatanReview, DateTime DiajukanPada, DateTime? TanggalMulai, DateTime? TanggalJatuhTempo, DateTime? DicairkanPada, decimal EstimasiBunga, decimal? BungaDibayar, bool PencairanDiajukan, DateTime? PencairanDiajukanPada, string? BuktiTransferUrl);

record AjukanPencairanRequest(string? Alasan);

record SimpananRekeningResponse(decimal Saldo, string? NomorRekening);
record SimpananWajibResponse(decimal Saldo, string? NomorRekening, decimal NominalBulanan, int TanggalTagih, List<TagihanWajibResponse> Tagihan);
record SimpananSukarelaResponse(decimal Saldo, string? NomorRekening, decimal BungaTahunan, decimal TarifPphBunga, List<TransaksiSukarelaResponse> Pengajuan);
record SimpananBerjangkaBagianResponse(decimal BungaTahunan, List<ProdukBerjangkaResponse> Produk, List<BerjangkaResponse> MilikSaya);
record SimpananSayaResponse(
    string StatusKeanggotaan,
    SimpananRekeningResponse Pokok,
    SimpananWajibResponse Wajib,
    SimpananSukarelaResponse Sukarela,
    SimpananBerjangkaBagianResponse Berjangka,
    List<MutasiResponse> MutasiTerakhir);

record HitungBungaRequest(string? Periode);

// ── Katalog produk ──────────────────────────────────────────────────────────
record ProdukResponse(
    int Id, string Kode, string Nama, string? Deskripsi, string Jenis, decimal Harga, decimal Stok, string Satuan,
    string? FotoUrl, string Sumber, string? DiajukanOleh, string Status, bool Aktif, string? CatatanReview);
record ProdukRequest(string Nama, string? Deskripsi, string Jenis, decimal Harga, decimal Stok, string Satuan);
record PutusanProdukRequest(bool Setuju, string? Catatan, decimal? Harga);
record BeliProdukRequest(decimal Jumlah, string? MetodePembayaran, string? Catatan);
record TagihanKreditRingkas(int Id, decimal Total, string Status);
record PembelianResponse(
    int Id, string NomorTransaksi, string ProdukNama, string Jenis, decimal Jumlah, decimal HargaSatuan, decimal Total,
    string MetodePembayaran, string Status, string? Catatan, string? CatatanReview, DateTime DiajukanPada, TagihanKreditRingkas? TagihanKredit);
record AdminPembelianResponse(
    int Id, string NomorTransaksi, string NamaPembeli, string NomorIndukKaryawan, string ProdukNama, string Jenis,
    decimal Jumlah, decimal HargaSatuan, decimal Total, string MetodePembayaran, string Status, string? Catatan,
    string? CatatanReview, DateTime DiajukanPada, DateTime? DiprosesPada);
record AdminTagihanKreditResponse(
    int Id, int PembelianProdukId, int PenggunaId, string NomorTransaksi, string NamaAnggota, string NomorIndukKaryawan, string ProdukNama,
    decimal Total, string Status, DateTime DibuatPada, DateTime? LunasPada);

record RekapTagihanRequest(int? PenggunaId, int? TagihanKreditId);
record SetujuiPeriodeRequest(string? Periode);
record PayrollItemResponse(string Jenis, int Id, string Keterangan, decimal Nominal);
record PayrollBarisResponse(int PenggunaId, string Nama, string Nik, decimal SimpananWajib, decimal TagihanKredit, decimal CicilanPinjaman, decimal SukarelaRutin, decimal TotalPotongan, List<PayrollItemResponse> Items);
record PayrollRekapResponse(string Periode, List<PayrollBarisResponse> Baris, decimal TotalWajib, decimal TotalKredit, decimal TotalCicilanPinjaman, decimal TotalSukarelaRutin, decimal TotalPotongan);

// ── Akuntansi ───────────────────────────────────────────────────────────────
record AkunResponse(int Id, string Kode, string Nama, string Tipe, string SaldoNormal, bool Sistem, bool Aktif);
record AkunRequest(string Kode, string Nama, string Tipe, string SaldoNormal);
record AkunPatchRequest(string? Nama, bool? Aktif);
record JurnalBarisRequest(int AkunId, decimal Debit, decimal Kredit);
record JurnalManualRequest(DateTime Tanggal, string Keterangan, List<JurnalBarisRequest> Baris);
record JurnalBarisResponse(int AkunId, string KodeAkun, string NamaAkun, decimal Debit, decimal Kredit);
record JurnalResponse(int Id, string NomorJurnal, DateTime Tanggal, string Keterangan, string Sumber, string? ReferensiModul, string? ReferensiId, string? DicatatOleh, List<JurnalBarisResponse> Baris);

// ── SHU ─────────────────────────────────────────────────────────────────────
record ShuHitungRequest(int Tahun, decimal TotalShu, decimal PersenAnggota, decimal PersenJasaModal, decimal PersenJasaUsaha, decimal PersenPengurus, decimal PersenCadangan);
record ShuRiwayatResponse(
    int Tahun, decimal TotalShu, decimal TotalPajak, decimal TotalShuNeto,
    decimal PersenAnggota, decimal PersenJasaModal, decimal PersenJasaUsaha, decimal PersenPengurus, decimal PersenCadangan,
    decimal JasaPengurusPool, decimal CadanganAmount, int JumlahAnggota, DateTime DifinalisasiPada);

record PengumumanResponse(string Ikon, string Judul, string Isi, string Tautan);

record BerandaRingkasanResponse(
    decimal TotalSimpanan,
    decimal SimpananPokok,
    decimal SimpananWajib,
    decimal SimpananSukarela,
    decimal SimpananBerjangka,
    int JumlahPinjamanAktif,
    decimal SisaPokokPinjaman,
    decimal CicilanBulananBerjalan,
    int SisaAngsuran,
    List<PengumumanResponse> Pengumuman,
    List<ProdukResponse> ProdukTerbaru,
    EstimasiShuResponse? EstimasiShu);

record EstimasiShuResponse(int Tahun, decimal TotalShu);
record ShuSayaResponse(
    int Tahun, decimal SimpananAnggota, decimal TransaksiAnggota,
    decimal Jma, decimal Jua, decimal TotalShu, decimal Pajak, decimal TotalShuNeto,
    decimal PersenAnggota, decimal PersenJasaModal, decimal PersenJasaUsaha, DateTime DifinalisasiPada);

record AdminTagihanWajibResponse(int Id, string NamaAnggota, string NomorIndukKaryawan, string Periode, decimal Nominal, DateTime JatuhTempo, string Status, string? CatatanReview, DateTime DibuatPada, DateTime? DiprosesPada);
record AdminTransaksiSukarelaResponse(int Id, string NamaAnggota, string NomorIndukKaryawan, string Jenis, decimal Nominal, string? Catatan, string Status, string? CatatanReview, DateTime DiajukanPada, DateTime? DiprosesPada, decimal SaldoSukarela, BungaSukarelaTerakhirResponse? BungaTerakhir, string? BuktiTransferUrl);
record BungaSukarelaTerakhirResponse(string Periode, decimal Bruto, decimal Pajak, decimal Neto);
record AdminBerjangkaResponse(int Id, string NamaAnggota, string NomorIndukKaryawan, string ProdukNama, string NomorSertifikat, decimal Nominal, int TenorBulan, string Status, string? CatatanReview, DateTime DiajukanPada, DateTime? TanggalMulai, DateTime? TanggalJatuhTempo, DateTime? DicairkanPada, decimal EstimasiBunga, decimal EstimasiPajak, decimal EstimasiBungaNeto, bool SudahDicairkan, bool PencairanDiajukan, DateTime? PencairanDiajukanPada, string? AlasanPencairan, string? BuktiTransferUrl);

record ToggleUserStatusRequest(bool Aktif);
record PeranRequest(string Peran);

record AdminUserResponse(
    int Id,
    string NamaLengkap,
    string NomorIndukKaryawan,
    string? Email,
    string Peran,
    string StatusKeanggotaan,
    bool Aktif,
    DateTime DibuatPada);

record AnggotaDirektoriResponse(
    int Id, string NamaLengkap, string NomorIndukKaryawan, string? Email, string Peran, string StatusKeanggotaan, bool Aktif,
    decimal TotalSimpanan, DateTime DibuatPada);

public record BerjangkaRingkasResponse(string NomorSertifikat, string ProdukNama, decimal Nominal, int TenorBulan, string Status, DateTime? TanggalMulai, DateTime? TanggalJatuhTempo);
public record PinjamanRingkasResponse(string NomorPinjaman, decimal Pokok, int TenorBulan, decimal AngsuranPerBulan, decimal SisaPokok, int AngsuranTerbayar, string Status, DateTime TanggalMulai, DateTime? LunasPada);
public record BelanjaRingkasResponse(string NomorTransaksi, string ProdukNama, string Jenis, decimal Jumlah, decimal Total, string MetodePembayaran, string Status, DateTime DiajukanPada);

public record AnggotaDetailResponse(
    int Id, string NamaLengkap, string NomorIndukKaryawan, string? Email, string? NomorTelepon, string? Alamat,
    string Peran, string StatusKeanggotaan, bool Aktif, DateTime DibuatPada, DateTime? DisetujuiPada,
    decimal SaldoPokok, decimal SaldoWajib, decimal SaldoSukarela, decimal SaldoBerjangka, decimal TotalSimpanan,
    List<BerjangkaRingkasResponse> Berjangka,
    List<PinjamanRingkasResponse> Pinjaman,
    List<BelanjaRingkasResponse> Belanja,
    decimal TotalTagihanKreditBelum,
    List<RiwayatSimpananResponse> RiwayatSimpanan);

public record RiwayatSimpananResponse(string JenisSimpanan, string Jenis, decimal Nominal, decimal SaldoSetelah, string? Keterangan, DateTime TanggalTransaksi);

record AuditLogResponse(
    int Id,
    DateTime WaktuUtc,
    int? PelakuId,
    string PelakuNama,
    string PelakuPeran,
    string Modul,
    string Aksi,
    int? EntitasId,
    string Ringkasan,
    string? Detail,
    string? AlamatIp);

// Hasil EXEC sp_VerifikasiDbAuditChain — hanya baris yang terindikasi bermasalah yang dikembalikan.
class BarisRantaiBermasalah
{
    public long Id { get; set; }
    public string Tabel { get; set; } = "";
    public string Operasi { get; set; } = "";
    public string KunciPrimer { get; set; } = "";
    public DateTime WaktuUtc { get; set; }
    public string DbLogin { get; set; } = "";
    public bool HashTidakCocok { get; set; }
    public bool RantaiTerputus { get; set; }
}
