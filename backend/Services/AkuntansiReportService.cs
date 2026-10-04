using Microsoft.EntityFrameworkCore;

public record SaldoAkunItem(string Kode, string Nama, decimal Saldo);
public record LabaRugiResult(DateTime Dari, DateTime Sampai, List<SaldoAkunItem> Pendapatan, decimal TotalPendapatan, List<SaldoAkunItem> Beban, decimal TotalBeban, decimal LabaBersih);
public record NeracaResult(DateTime Tanggal, List<SaldoAkunItem> Aset, decimal TotalAset, List<SaldoAkunItem> Liabilitas, decimal TotalLiabilitas, List<SaldoAkunItem> Ekuitas, decimal ShuBerjalan, decimal TotalEkuitas, decimal Selisih, string? Catatan = null);
public record ArusKasBaris(DateTime Tanggal, string NomorJurnal, string Keterangan, string? Modul, decimal Masuk, decimal Keluar);
public record ArusKasResult(DateTime Dari, DateTime Sampai, decimal SaldoAwal, decimal TotalMasuk, decimal TotalKeluar, decimal SaldoAkhir, List<ArusKasBaris> Baris);
public record BukuBesarAkunItem(string Kode, string Nama, string Tipe, decimal SaldoAwal, decimal Debit, decimal Kredit, decimal SaldoAkhir);

/// <summary>
/// Laporan keuangan dihitung langsung dari buku besar (JurnalBaris) — bukan tabel saldo terpisah,
/// jadi selalu konsisten dengan jurnal yang sudah diposting (otomatis maupun manual).
/// Arus Kas di sini adalah ringkasan kas masuk/keluar metode langsung sederhana (bukan klasifikasi
/// operasi/investasi/pendanaan penuh sesuai SAK) — cukup untuk pemantauan internal pengurus.
/// </summary>
public static class AkuntansiReportService
{
    private static decimal SaldoNormalDebit(string saldoNormal, decimal debit, decimal kredit) =>
        saldoNormal == "Debit" ? debit - kredit : kredit - debit;

    public static async Task<LabaRugiResult> HitungLabaRugiAsync(KkcsDbContext db, DateTime dari, DateTime sampai)
    {
        var akhir = sampai.Date.AddDays(1).AddTicks(-1);
        var akun = await db.AkunAkuntansi.AsNoTracking().Where(a => a.Tipe == "Pendapatan" || a.Tipe == "Beban")
            .Select(a => new
            {
                a.Kode,
                a.Nama,
                a.Tipe,
                a.SaldoNormal,
                Debit = a.Baris.Where(b => b.JurnalEntri.Tanggal >= dari.Date && b.JurnalEntri.Tanggal <= akhir).Sum(b => (decimal?)b.Debit) ?? 0,
                Kredit = a.Baris.Where(b => b.JurnalEntri.Tanggal >= dari.Date && b.JurnalEntri.Tanggal <= akhir).Sum(b => (decimal?)b.Kredit) ?? 0
            })
            .ToListAsync();

        var pendapatan = akun.Where(a => a.Tipe == "Pendapatan")
            .Select(a => new SaldoAkunItem(a.Kode, a.Nama, SaldoNormalDebit(a.SaldoNormal, a.Debit, a.Kredit)))
            .Where(a => a.Saldo != 0).OrderBy(a => a.Kode).ToList();
        var beban = akun.Where(a => a.Tipe == "Beban")
            .Select(a => new SaldoAkunItem(a.Kode, a.Nama, SaldoNormalDebit(a.SaldoNormal, a.Debit, a.Kredit)))
            .Where(a => a.Saldo != 0).OrderBy(a => a.Kode).ToList();

        var totalPendapatan = pendapatan.Sum(a => a.Saldo);
        var totalBeban = beban.Sum(a => a.Saldo);
        return new LabaRugiResult(dari.Date, sampai.Date, pendapatan, totalPendapatan, beban, totalBeban, totalPendapatan - totalBeban);
    }

    public static async Task<NeracaResult> HitungNeracaAsync(KkcsDbContext db, DateTime tanggal)
    {
        var akhir = tanggal.Date.AddDays(1).AddTicks(-1);
        var akun = await db.AkunAkuntansi.AsNoTracking().Where(a => a.Tipe == "Aset" || a.Tipe == "Liabilitas" || a.Tipe == "Ekuitas")
            .Select(a => new
            {
                a.Kode,
                a.Nama,
                a.Tipe,
                a.SaldoNormal,
                Debit = a.Baris.Where(b => b.JurnalEntri.Tanggal <= akhir).Sum(b => (decimal?)b.Debit) ?? 0,
                Kredit = a.Baris.Where(b => b.JurnalEntri.Tanggal <= akhir).Sum(b => (decimal?)b.Kredit) ?? 0
            })
            .ToListAsync();

        List<SaldoAkunItem> Bagian(string tipe) => akun.Where(a => a.Tipe == tipe)
            .Select(a => new SaldoAkunItem(a.Kode, a.Nama, SaldoNormalDebit(a.SaldoNormal, a.Debit, a.Kredit)))
            .Where(a => a.Saldo != 0).OrderBy(a => a.Kode).ToList();

        var aset = Bagian("Aset");
        var liabilitas = Bagian("Liabilitas");
        var ekuitas = Bagian("Ekuitas");

        // SHU tahun berjalan (sejak awal tahun kalender dari `tanggal`) dimasukkan ke Ekuitas agar Neraca balance,
        // sebelum diapropriasi lewat finalisasi SHU (yang memindahkannya ke akun Utang SHU Anggota).
        var awalTahun = new DateTime(tanggal.Year, 1, 1);
        var labaRugiBerjalan = await HitungLabaRugiAsync(db, awalTahun, tanggal);

        var totalAset = aset.Sum(a => a.Saldo);
        var totalLiabilitas = liabilitas.Sum(a => a.Saldo);
        var totalEkuitas = ekuitas.Sum(a => a.Saldo) + labaRugiBerjalan.LabaBersih;

        return new NeracaResult(tanggal.Date, aset, totalAset, liabilitas, totalLiabilitas, ekuitas, labaRugiBerjalan.LabaBersih, totalEkuitas, totalAset - (totalLiabilitas + totalEkuitas));
    }

    public static async Task<ArusKasResult> HitungArusKasAsync(KkcsDbContext db, DateTime dari, DateTime sampai)
    {
        var akun = await db.AkunAkuntansi.AsNoTracking().FirstOrDefaultAsync(a => a.Kode == KodeAkun.Kas);
        if (akun is null) return new ArusKasResult(dari.Date, sampai.Date, 0, 0, 0, 0, []);

        var akhir = sampai.Date.AddDays(1).AddTicks(-1);
        var sebelum = await db.JurnalBaris.AsNoTracking().Include(b => b.JurnalEntri)
            .Where(b => b.AkunId == akun.Id && b.JurnalEntri.Tanggal < dari.Date)
            .ToListAsync();
        var saldoAwal = sebelum.Sum(b => b.Debit - b.Kredit);

        var periode = await db.JurnalBaris.AsNoTracking().Include(b => b.JurnalEntri)
            .Where(b => b.AkunId == akun.Id && b.JurnalEntri.Tanggal >= dari.Date && b.JurnalEntri.Tanggal <= akhir)
            .OrderBy(b => b.JurnalEntri.Tanggal).ThenBy(b => b.Id)
            .Select(b => new ArusKasBaris(b.JurnalEntri.Tanggal, b.JurnalEntri.NomorJurnal, b.JurnalEntri.Keterangan, b.JurnalEntri.ReferensiModul, b.Debit, b.Kredit))
            .ToListAsync();

        var totalMasuk = periode.Sum(b => b.Masuk);
        var totalKeluar = periode.Sum(b => b.Keluar);
        return new ArusKasResult(dari.Date, sampai.Date, saldoAwal, totalMasuk, totalKeluar, saldoAwal + totalMasuk - totalKeluar, periode);
    }

    /// <summary>
    /// Buku besar satu tahun buku per akun — Saldo Awal (posisi per 1 Jan), Debit & Kredit selama tahun
    /// tersebut, dan Saldo Akhir (posisi per 31 Des) — gaya "Penjelasan Pos Neraca/SHU" pada laporan RAT.
    /// Hanya akun yang punya saldo awal, mutasi, atau saldo akhir tidak nol yang disertakan.
    /// </summary>
    public static async Task<List<BukuBesarAkunItem>> HitungBukuBesarTahunanAsync(KkcsDbContext db, int tahun)
    {
        var awalTahun = new DateTime(tahun, 1, 1);
        var akhirTahun = new DateTime(tahun, 12, 31, 23, 59, 59, 999);

        var akun = await db.AkunAkuntansi.AsNoTracking()
            .Select(a => new
            {
                a.Kode,
                a.Nama,
                a.Tipe,
                a.SaldoNormal,
                DebitSebelum = a.Baris.Where(b => b.JurnalEntri.Tanggal < awalTahun).Sum(b => (decimal?)b.Debit) ?? 0,
                KreditSebelum = a.Baris.Where(b => b.JurnalEntri.Tanggal < awalTahun).Sum(b => (decimal?)b.Kredit) ?? 0,
                DebitTahunIni = a.Baris.Where(b => b.JurnalEntri.Tanggal >= awalTahun && b.JurnalEntri.Tanggal <= akhirTahun).Sum(b => (decimal?)b.Debit) ?? 0,
                KreditTahunIni = a.Baris.Where(b => b.JurnalEntri.Tanggal >= awalTahun && b.JurnalEntri.Tanggal <= akhirTahun).Sum(b => (decimal?)b.Kredit) ?? 0,
            })
            .ToListAsync();

        return akun.Select(a =>
        {
            var saldoAwal = SaldoNormalDebit(a.SaldoNormal, a.DebitSebelum, a.KreditSebelum);
            var saldoAkhir = SaldoNormalDebit(a.SaldoNormal, a.DebitSebelum + a.DebitTahunIni, a.KreditSebelum + a.KreditTahunIni);
            return new BukuBesarAkunItem(a.Kode, a.Nama, a.Tipe, saldoAwal, a.DebitTahunIni, a.KreditTahunIni, saldoAkhir);
        })
        .Where(a => a.SaldoAwal != 0 || a.Debit != 0 || a.Kredit != 0 || a.SaldoAkhir != 0)
        .OrderBy(a => a.Kode)
        .ToList();
    }
}
