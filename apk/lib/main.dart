import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const KkcsApp());
}

abstract final class KkcsColors {
  // Palet Biru Tosca & Biru Tua sesuai tampilan admin pengurus
  static const primary = Color(0xFF0891B2);      // Tosca Utama (Cyan 600)
  static const primaryDark = Color(0xFF0E7490);  // Tosca Gelap (Cyan 700)
  static const primaryDeep = Color(0xFF083344);  // Biru Tua / Navy (Cyan 950)
  static const primaryLight = Color(0xFFECFEFF); // Tosca Sangat Lembut (Cyan 50)
  static const mint = Color(0xFFCFFAFE);         // Mint Pastel (Cyan 100)

  // Netral
  static const background = Color(0xFFF6FAFB);   // Cool Grey-Cyan Background
  static const surface = Color(0xFFFFFFFF);      // Putih Card / Surface
  static const border = Color(0xFFDBE8EA);       // Line / Border Halus
  static const borderLight = Color(0xFFEDF6F7);  // Divider Halus
  static const borderSubtle = Color(0xFFE2E8F0); // Border Netral Halus

  // Tipografi
  static const textPrimary = Color(0xFF0F172A);  // Dark Ink (Slate 900)
  static const textSecondary = Color(0xFF53717D);// Slate Muted
  static const textMuted = Color(0xFF64748B);    // Slate 500
  static const textDisabled = Color(0xFF94A3B8); // Slate 400

  // Semantik & Status
  static const success = Color(0xFF059669);      // Emerald 600
  static const successBg = Color(0xFFECFDF5);    // Emerald 50
  static const warning = Color(0xFFD97706);      // Amber 600
  static const warningBg = Color(0xFFFFFBEB);    // Amber 50
  static const danger = Color(0xFFDC2626);       // Red 600
  static const dangerBg = Color(0xFFFEF2F2);     // Red 50
  static const info = Color(0xFF0284C7);         // Sky 600
  static const infoBg = Color(0xFFF0F9FF);       // Sky 50

  // Gradien Khas
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primaryDark, primary],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8FAFC), Colors.white],
  );
}

class KkcsApp extends StatelessWidget {
  const KkcsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KKCS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: KkcsColors.primary,
          onPrimary: Colors.white,
          primaryContainer: KkcsColors.primaryLight,
          onPrimaryContainer: KkcsColors.primaryDeep,
          secondary: KkcsColors.primaryDark,
          onSecondary: Colors.white,
          secondaryContainer: KkcsColors.mint,
          onSecondaryContainer: KkcsColors.primaryDeep,
          tertiary: KkcsColors.info,
          onTertiary: Colors.white,
          tertiaryContainer: KkcsColors.infoBg,
          onTertiaryContainer: Color(0xFF0369A1),
          error: KkcsColors.danger,
          onError: Colors.white,
          errorContainer: KkcsColors.dangerBg,
          onErrorContainer: Color(0xFF991B1B),
          surface: KkcsColors.surface,
          onSurface: KkcsColors.textPrimary,
          onSurfaceVariant: KkcsColors.textSecondary,
          outline: KkcsColors.border,
          outlineVariant: KkcsColors.borderLight,
        ),
        scaffoldBackgroundColor: KkcsColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: KkcsColors.primaryDeep,
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: KkcsColors.primaryDeep,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
          iconTheme: IconThemeData(color: KkcsColors.primaryDeep),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: KkcsColors.border, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: KkcsColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: KkcsColors.primary,
            side: const BorderSide(color: KkcsColors.primary, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: KkcsColors.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: KkcsColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: KkcsColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: KkcsColors.primary, width: 1.8),
          ),
          labelStyle: const TextStyle(color: KkcsColors.textSecondary, fontSize: 14),
          floatingLabelStyle: const TextStyle(color: KkcsColors.primary, fontWeight: FontWeight.w600),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: KkcsColors.primary,
          unselectedLabelColor: KkcsColors.textSecondary,
          indicatorColor: KkcsColors.primary,
          labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: KkcsColors.primaryLight,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: KkcsColors.primary);
            }
            return const IconThemeData(color: KkcsColors.textSecondary);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: KkcsColors.primary, fontWeight: FontWeight.w800, fontSize: 12);
            }
            return const TextStyle(color: KkcsColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12);
          }),
        ),
        dataTableTheme: DataTableThemeData(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF6FAFB)),
          headingTextStyle: const TextStyle(
            color: KkcsColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
          dataTextStyle: const TextStyle(
            color: KkcsColors.textPrimary,
            fontSize: 12.5,
          ),
          dividerThickness: 1,
        ),
        dividerTheme: const DividerThemeData(
          color: KkcsColors.borderLight,
          thickness: 1,
          space: 20,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: KkcsColors.primaryDeep, fontWeight: FontWeight.w800),
          headlineMedium: TextStyle(color: KkcsColors.primaryDeep, fontWeight: FontWeight.w800),
          headlineSmall: TextStyle(color: KkcsColors.primaryDeep, fontWeight: FontWeight.w800),
          titleLarge: TextStyle(color: KkcsColors.primaryDeep, fontWeight: FontWeight.w800),
          titleMedium: TextStyle(color: KkcsColors.primaryDeep, fontWeight: FontWeight.w700),
          titleSmall: TextStyle(color: KkcsColors.primaryDeep, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(color: KkcsColors.textPrimary),
          bodyMedium: TextStyle(color: KkcsColors.textPrimary),
          bodySmall: TextStyle(color: KkcsColors.textSecondary),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.namaLengkap,
    required this.nomorIndukKaryawan,
    this.statusKeanggotaan = 'Aktif',
    this.email,
    this.nomorTelepon,
    this.alamat,
    this.fotoUrl,
  });

  final int id;
  final String namaLengkap;
  final String nomorIndukKaryawan;
  final String statusKeanggotaan;
  final String? email;
  final String? nomorTelepon;
  final String? alamat;
  final String? fotoUrl;

  bool get anggotaAktif => statusKeanggotaan == 'Aktif';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int,
      namaLengkap: json['namaLengkap'] as String,
      nomorIndukKaryawan: json['nomorIndukKaryawan'] as String,
      statusKeanggotaan: json['statusKeanggotaan'] as String? ?? 'Aktif',
      email: json['email'] as String?,
      nomorTelepon: json['nomorTelepon'] as String?,
      alamat: json['alamat'] as String?,
      fotoUrl: json['fotoUrl'] as String?,
    );
  }
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AuthUser user;
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  static const _tokenKey = 'kkcs_auth_token';

  static String get baseUrl {
    if (kReleaseMode) return 'https://api.kopkkcs-gcs.tech';
    if (kIsWeb) return 'http://localhost:5168';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5168';
    }
    return 'http://localhost:5168';
  }

  Future<AuthSession?> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    if (token == null || token.isEmpty) return null;

    try {
      final user = await currentUser(token);
      return AuthSession(token: token, user: user);
    } catch (_) {
      await preferences.remove(_tokenKey);
      return null;
    }
  }

  Future<AuthSession> login({required String nomorIndukKaryawan, required String password}) async {
    final response = await _sendRequest(() => http.post(
          Uri.parse('$baseUrl/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'nomorIndukKaryawan': nomorIndukKaryawan.trim(), 'password': password}),
        ));
    final session = _sessionFromResponse(response);
    await _saveToken(session.token);
    return session;
  }

  Future<AuthSession> register({
    required String namaLengkap,
    required String nomorIndukKaryawan,
    String? email,
    required String password,
  }) async {
    final response = await _sendRequest(() => http.post(
          Uri.parse('$baseUrl/api/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'namaLengkap': namaLengkap.trim(),
            'nomorIndukKaryawan': nomorIndukKaryawan.trim(),
            'email': email?.trim(),
            'password': password,
          }),
        ));
    final session = _sessionFromResponse(response);
    await _saveToken(session.token);
    return session;
  }

  Future<AuthUser> currentUser(String token) async {
    final response = await _sendRequest(() => http.get(
          Uri.parse('$baseUrl/api/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _ensureSuccess(response);
    return AuthUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<CatalogProduct>> _getProductList(String path) async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.get(
          Uri.parse('$baseUrl$path'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _ensureSuccess(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((e) => CatalogProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EratAgendaItem>> fetchEratAgenda() async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.get(
          Uri.parse('$baseUrl/api/erat/agenda'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _ensureSuccess(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((e) => EratAgendaItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> submitVote({required int agendaId, required int opsiId}) async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.post(
          Uri.parse('$baseUrl/api/erat/agenda/$agendaId/suara'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'opsiId': opsiId}),
        ));
    _ensureSuccess(response);
  }

  Future<List<RatDocument>> fetchRatDocuments() async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.get(
          Uri.parse('$baseUrl/api/erat/laporan-tahunan'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _ensureSuccess(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((e) => RatDocument.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Laporan RAT otomatis yang sudah ditayangkan pengurus. Null jika belum ada yang ditayangkan.
  Future<LaporanRatTahunan?> fetchLaporanRatTerbaru() async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.get(
          Uri.parse('$baseUrl/api/erat/laporan-rat-tahunan'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    if (response.statusCode == 404) return null;
    _ensureSuccess(response);
    return LaporanRatTahunan.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<CatalogProduct>> fetchCatalog() => _getProductList('/api/produk');
  Future<List<CatalogProduct>> fetchMyListings() => _getProductList('/api/produk/pengajuan/saya');

  Future<CatalogProduct> submitProductListing({
    required String nama,
    String? deskripsi,
    required String jenis,
    required double harga,
    required double stok,
    required String satuan,
  }) async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.post(
          Uri.parse('$baseUrl/api/produk/pengajuan'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'nama': nama.trim(),
            'deskripsi': deskripsi?.trim(),
            'jenis': jenis,
            'harga': harga,
            'stok': stok,
            'satuan': satuan.trim(),
          }),
        ));
    _ensureSuccess(response);
    return CatalogProduct.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> uploadProductListingPhoto(int produkId, XFile photo) async {
    final token = await _getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/produk/pengajuan/$produkId/foto'))
      ..headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('file', await photo.readAsBytes(),
        filename: photo.name, contentType: _photoMediaType(photo)));
    final response = await http.Response.fromStream(await request.send());
    _ensureSuccess(response);
  }

  Future<void> buyProduct({
    required int produkId,
    required double jumlah,
    required String metodePembayaran,
    String? catatan,
  }) async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.post(
          Uri.parse('$baseUrl/api/produk/$produkId/beli'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'jumlah': jumlah, 'metodePembayaran': metodePembayaran, 'catatan': catatan?.trim()}),
        ));
    _ensureSuccess(response);
  }

  Future<List<ProductPurchase>> fetchMyPurchases() async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.get(
          Uri.parse('$baseUrl/api/produk/pembelian/saya'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _ensureSuccess(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((e) => ProductPurchase.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> submitLoan({required double nominal, required int tenorBulan, required String tujuan}) async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.post(
          Uri.parse('$baseUrl/api/pinjaman'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'nominal': nominal,
            'tenorBulan': tenorBulan,
            'tujuan': tujuan.trim(),
          }),
        ));
    _ensureSuccess(response);
  }

  Future<LoanOverview> fetchMyLoans() async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.get(
          Uri.parse('$baseUrl/api/pinjaman/saya'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _ensureSuccess(response);
    return LoanOverview.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// [jenis] = 'Angsuran' atau 'Pelunasan'. Diajukan anggota, disetujui pengurus.
  /// Unduh draft pengajuan pinjaman (PDF) lalu buka dengan viewer PDF bawaan perangkat.
  Future<void> downloadAndOpenLoanDraft({required int pengajuanId, required String nomorPengajuan}) async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.get(
          Uri.parse('$baseUrl/api/pinjaman/$pengajuanId/draft/pdf'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _ensureSuccess(response);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Draft-Pinjaman-$nomorPengajuan.pdf');
    await file.writeAsBytes(response.bodyBytes);
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      throw Exception('Tidak bisa membuka PDF: ${result.message}');
    }
  }

  /// Unduh manual book panduan anggota (PDF) lalu buka dengan viewer PDF bawaan perangkat.
  Future<void> downloadAndOpenManualBookAnggota() async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.get(
          Uri.parse('$baseUrl/api/panduan/anggota/pdf'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _ensureSuccess(response);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Manual-Book-Anggota-KKCS.pdf');
    await file.writeAsBytes(response.bodyBytes);
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      throw Exception('Tidak bisa membuka PDF: ${result.message}');
    }
  }

  Future<void> uploadLoanRecommendation({required int pengajuanId, required PlatformFile file}) async {
    final token = await _getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/pinjaman/$pengajuanId/rekomendasi'))
      ..headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('file', file.bytes!,
        filename: file.name, contentType: _buktiMediaType(file.name)));
    final response = await http.Response.fromStream(await request.send());
    _ensureSuccess(response);
  }

  Future<void> requestLoanPayment({required int loanId, required String jenis, PlatformFile? bukti}) async {
    final token = await _getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/pinjaman/$loanId/pembayaran'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['jenis'] = jenis;
    if (bukti != null) {
      request.files.add(http.MultipartFile.fromBytes('bukti', bukti.bytes!,
          filename: bukti.name, contentType: _buktiMediaType(bukti.name)));
    }
    final response = await http.Response.fromStream(await request.send());
    _ensureSuccess(response);
  }

  Future<HomeSummary> fetchHomeSummary() async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.get(
          Uri.parse('$baseUrl/api/beranda/ringkasan'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _ensureSuccess(response);
    return HomeSummary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<SavingsOverview> fetchSavings() async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.get(
          Uri.parse('$baseUrl/api/simpanan/saya'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _ensureSuccess(response);
    return SavingsOverview.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<PersonalCashFlow> fetchCashFlow() async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.get(
          Uri.parse('$baseUrl/api/akun/arus-kas'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _ensureSuccess(response);
    return PersonalCashFlow.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<ShuHistoryEntry>> fetchMyShu() async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.get(
          Uri.parse('$baseUrl/api/shu/saya'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _ensureSuccess(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((e) => ShuHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// [jenis] = 'Setor' atau 'Tarik'. [bukti] wajib diisi untuk Setor.
  Future<void> requestSukarela({required String jenis, required double nominal, PlatformFile? bukti}) async {
    final token = await _getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/simpanan/sukarela'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['jenis'] = jenis
      ..fields['nominal'] = nominal.toString();
    if (bukti != null) {
      request.files.add(http.MultipartFile.fromBytes('bukti', bukti.bytes!,
          filename: bukti.name, contentType: _buktiMediaType(bukti.name)));
    }
    final response = await http.Response.fromStream(await request.send());
    _ensureSuccess(response);
  }

  Future<SukarelaRutinInfo?> fetchSukarelaRutin() async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.get(
          Uri.parse('$baseUrl/api/simpanan/sukarela-rutin/saya'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _ensureSuccess(response);
    if (response.body == 'null' || response.body.isEmpty) return null;
    return SukarelaRutinInfo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> submitSukarelaRutin({required double nominal, required int tanggalSetor}) async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.post(
          Uri.parse('$baseUrl/api/simpanan/sukarela-rutin'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'nominal': nominal, 'tanggalSetor': tanggalSetor}),
        ));
    _ensureSuccess(response);
  }

  Future<void> stopSukarelaRutin(int id) async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.post(
          Uri.parse('$baseUrl/api/simpanan/sukarela-rutin/$id/berhenti'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    _ensureSuccess(response);
  }

  Future<void> requestBerjangka({required int produkId, required PlatformFile bukti}) async {
    final token = await _getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/simpanan/berjangka'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['produkBerjangkaId'] = produkId.toString();
    request.files.add(http.MultipartFile.fromBytes('bukti', bukti.bytes!,
        filename: bukti.name, contentType: _buktiMediaType(bukti.name)));
    final response = await http.Response.fromStream(await request.send());
    _ensureSuccess(response);
  }

  Future<void> requestEarlyWithdrawal({required int berjangkaId}) async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.post(
          Uri.parse('$baseUrl/api/simpanan/berjangka/$berjangkaId/pencairan'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({}),
        ));
    _ensureSuccess(response);
  }

  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
  }

  Future<AuthUser> updateProfile({
    required String namaLengkap,
    String? email,
    String? nomorTelepon,
    String? alamat,
  }) async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.put(
          Uri.parse('$baseUrl/api/auth/profile'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'namaLengkap': namaLengkap.trim(),
            'email': email?.trim(),
            'nomorTelepon': nomorTelepon?.trim(),
            'alamat': alamat?.trim(),
          }),
        ));
    _ensureSuccess(response);
    return AuthUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> changePassword({required String passwordLama, required String passwordBaru}) async {
    final token = await _getToken();
    final response = await _sendRequest(() => http.post(
          Uri.parse('$baseUrl/api/auth/ganti-password'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'passwordLama': passwordLama, 'passwordBaru': passwordBaru}),
        ));
    _ensureSuccess(response);
  }

  Future<AuthUser> uploadProfilePhoto(XFile photo) async {
    final token = await _getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/auth/profile/photo'))
      ..headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      await photo.readAsBytes(),
      filename: photo.name,
      contentType: _photoMediaType(photo),
    ));
    final response = await http.Response.fromStream(await request.send());
    _ensureSuccess(response);
    return AuthUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  MediaType _buktiMediaType(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    return switch (extension) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'pdf' => MediaType('application', 'pdf'),
      _ => MediaType('application', 'octet-stream'),
    };
  }

  MediaType _photoMediaType(XFile photo) {
    final mimeType = photo.mimeType;
    if (mimeType != null && mimeType.startsWith('image/')) {
      return MediaType.parse(mimeType);
    }

    final extension = photo.name.toLowerCase().split('.').last;
    return switch (extension) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'png'),
    };
  }

  Future<String> _getToken() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    if (token == null || token.isEmpty) throw const ApiException('Sesi login sudah berakhir.');
    return token;
  }

  Future<void> _saveToken(String token) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
  }

  Future<http.Response> _sendRequest(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on http.ClientException {
      throw ApiException('Tidak dapat terhubung ke server ($baseUrl). Periksa koneksi internet Anda.');
    }
  }

  AuthSession _sessionFromResponse(http.Response response) {
    _ensureSuccess(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthSession(
      token: json['token'] as String,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiException(_errorMessage(response));
  }

  String _errorMessage(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['message'] is String) return json['message'] as String;
      final errors = json['errors'];
      if (errors is Map<String, dynamic>) {
        final messages = errors.values
            .whereType<List<dynamic>>()
            .expand((items) => items)
            .whereType<String>()
            .toList();
        if (messages.isNotEmpty) return messages.join(' ');
      }
    } catch (_) {
      // Use the status message when the response is not JSON.
    }
    if (response.statusCode == 401) return 'NIK atau password salah.';
    return 'Terjadi kesalahan pada server (${response.statusCode}).';
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return FutureBuilder<AuthSession?>(
      future: auth.restoreSession(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final session = snapshot.data;
        return session == null
            ? LandingPage(auth: auth)
            : HomePage(auth: auth, session: session);
      },
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({required this.auth, super.key});

  final AuthService auth;

  Widget _featurePill({required IconData icon, required String title, required String subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KkcsColors.border),
        boxShadow: [
          BoxShadow(
            color: KkcsColors.primaryDeep.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: KkcsColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: KkcsColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: KkcsColors.primaryDeep,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: KkcsColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KkcsColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _BrandMark(size: 58),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: KkcsColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: KkcsColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 13, color: KkcsColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'Koperasi Resmi',
                              style: TextStyle(
                                color: KkcsColors.primaryDeep,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Layanan koperasi\ndalam satu ruang.',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: KkcsColors.primaryDeep,
                          height: 1.12,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Selamat datang di KKCS. Akses layanan anggota dengan mudah, transparan, dan terarah.',
                    style: const TextStyle(
                      color: KkcsColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _featurePill(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Simpan Pinjam Mandiri',
                    subtitle: 'Pengajuan pinjaman & pantau simpanan secara realtime',
                  ),
                  _featurePill(
                    icon: Icons.storefront_outlined,
                    title: 'Katalog & Unit Usaha',
                    subtitle: 'Belanja produk kebutuhan dan kanal penjualan anggota',
                  ),
                  _featurePill(
                    icon: Icons.how_to_vote_outlined,
                    title: 'E-RAT & Transparansi SHU',
                    subtitle: 'Voting digital keputusan tahunan dan kalkulasi dividen',
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => LoginPage(auth: auth)),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: KkcsColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 1,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Masuk ke akun', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RegisterPage(auth: auth)),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: KkcsColors.primary,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: KkcsColors.primary, width: 1.4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Buat akun baru', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Center(
                    child: Text(
                      'KKCS Mobile • Versi 2.0.0',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: KkcsColors.textDisabled,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({required this.auth, super.key});

  final AuthService auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nikController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _nikController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.auth.login(
        nomorIndukKaryawan: _nikController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomePage(auth: widget.auth, session: session)),
        (_) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Selamat datang kembali',
      subtitle: 'Masuk untuk mengakses portal mandiri dan layanan koperasi Anda.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ErrorMessage(message: _error),
            TextFormField(
              controller: _nikController,
              decoration: const InputDecoration(
                labelText: 'Nomor Induk Karyawan (NIK)',
                hintText: 'Contoh: NIK-001',
                prefixIcon: Icon(Icons.badge_outlined, size: 20, color: KkcsColors.primary),
              ),
              validator: _requiredNik,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Masukkan kata sandi',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: KkcsColors.primary),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: KkcsColors.textSecondary,
                  ),
                  tooltip: 'Tampilkan password',
                ),
              ),
              validator: (value) => value == null || value.isEmpty ? 'Password wajib diisi' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: KkcsColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const _ButtonLoader()
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Masuk', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: KkcsColors.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Belum punya akun?', style: TextStyle(fontSize: 13, color: KkcsColors.textSecondary)),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => RegisterPage(auth: widget.auth)),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Daftar di sini',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: KkcsColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({required this.auth, super.key});

  final AuthService auth;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nikController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _nikController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.auth.register(
        namaLengkap: _nameController.text,
        nomorIndukKaryawan: _nikController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomePage(auth: widget.auth, session: session)),
        (_) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Buat akun KKCS',
      subtitle: 'Daftarkan akun anggota baru untuk mengakses seluruh layanan koperasi.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ErrorMessage(message: _error),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama lengkap',
                hintText: 'Nama lengkap sesuai KTP',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: KkcsColors.primary),
              ),
              validator: (value) => value == null || value.trim().isEmpty ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nikController,
              decoration: const InputDecoration(
                labelText: 'Nomor Induk Karyawan (NIK)',
                hintText: 'Contoh: NIK-001',
                prefixIcon: Icon(Icons.badge_outlined, size: 20, color: KkcsColors.primary),
              ),
              validator: _requiredNik,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (opsional)',
                hintText: 'nama@perusahaan.com',
                prefixIcon: Icon(Icons.email_outlined, size: 20, color: KkcsColors.primary),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Minimal 8 karakter',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: KkcsColors.primary),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: KkcsColors.textSecondary,
                  ),
                  tooltip: 'Tampilkan password',
                ),
              ),
              validator: (value) => value != null && value.length >= 8 ? null : 'Minimal 8 karakter',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmController,
              obscureText: !_showPassword,
              decoration: const InputDecoration(
                labelText: 'Konfirmasi password',
                hintText: 'Ulangi kata sandi di atas',
                prefixIcon: Icon(Icons.lock_reset_rounded, size: 20, color: KkcsColors.primary),
              ),
              validator: (value) => value == _passwordController.text ? null : 'Password belum sama',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KkcsColors.infoBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: KkcsColors.info.withValues(alpha: 0.2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: KkcsColors.info),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Setelah mendaftar, keanggotaan Anda akan diverifikasi oleh pengurus sebelum transaksi dapat dilakukan.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF0369A1), height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: KkcsColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const _ButtonLoader()
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Daftar Akun', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: KkcsColors.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Sudah punya akun?', style: TextStyle(fontSize: 13, color: KkcsColors.textSecondary)),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => LoginPage(auth: widget.auth)),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Masuk ke akun',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: KkcsColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({required this.auth, required this.session, super.key});

  final AuthService auth;
  final AuthSession session;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  String? _error;
  HomeSummary? _summary;

  @override
  void initState() {
    super.initState();
    if (widget.session.user.anggotaAktif) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await widget.auth.fetchHomeSummary();
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _servicePage(int index) {
    return switch (index) {
      1 => DigitalSavingsLoanPage(session: widget.session),
      2 => BusinessUnitPage(session: widget.session),
      3 => EratPage(session: widget.session),
      _ => AccountPage(auth: widget.auth, session: widget.session),
    };
  }

  Future<void> _openService(int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ServiceShell(
          auth: widget.auth,
          session: widget.session,
          selectedIndex: index,
          child: _servicePage(index),
        ),
      ),
    );
    if (mounted) _load();
  }

  void _openTautan(String tautan) {
    switch (tautan) {
      case 'erat':
        _openService(3);
      case 'katalog':
        _openService(2);
      case 'simpanan':
      case 'pinjaman':
        _openService(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.session.user.anggotaAktif) {
      return MembershipStatusPage(auth: widget.auth, user: widget.session.user);
    }
    final s = _summary;
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: Image.asset('assets/logo_kkcs.png', fit: BoxFit.contain),
          ),
        ),
        title: const Text('Beranda KKCS'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PanduanAnggotaPage()),
            ),
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Panduan Anggota',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => _openService(0),
              icon: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: KkcsColors.primary, width: 1.5),
                ),
                child: _ProfileAvatar(user: widget.session.user, radius: 15),
              ),
              tooltip: 'Akun saya',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Halo, ${widget.session.user.namaLengkap.split(' ').first}',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: KkcsColors.primaryDeep,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: KkcsColors.successBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: KkcsColors.success.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified, size: 12, color: KkcsColors.success),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.session.user.statusKeanggotaan,
                                    style: const TextStyle(color: KkcsColors.success, fontSize: 10.5, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Akses layanan anggota dan transparansi koperasi dalam satu tempat.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: KkcsColors.textSecondary, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _TransparencyDashboard(session: widget.session, summary: s, loading: _loading, error: _error, onRefresh: _load),
              const SizedBox(height: 22),
              _HomeAnnouncementCard(items: s?.pengumuman ?? const [], onOpen: _openTautan),
              const SizedBox(height: 22),
              _LatestProductsPreview(products: s?.produkTerbaru ?? const [], onOpenCatalog: () => _openService(2)),
              const SizedBox(height: 22),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app_outlined, size: 14, color: KkcsColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Pilih layanan dari navigasi di bawah.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: KkcsColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 0) return;
          _openService(index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Simpan Pinjam'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Katalog'),
          NavigationDestination(icon: Icon(Icons.how_to_vote_outlined), label: 'E-RAT'),
        ],
      ),
    );
  }
}

class _PanduanModul {
  const _PanduanModul({required this.icon, required this.judul, required this.ringkasan, required this.poin});

  final IconData icon;
  final String judul;
  final String ringkasan;
  final List<String> poin;
}

const _panduanAnggotaModules = [
  _PanduanModul(
    icon: Icons.how_to_reg_outlined,
    judul: 'Daftar & Masuk Aplikasi',
    ringkasan: 'Langkah pertama sebelum bisa menikmati semua layanan koperasi lewat aplikasi.',
    poin: [
      'Buka aplikasi lalu pilih "Daftar" — isi data diri (NIK, nama lengkap, email, nomor telepon) dan buat password.',
      'Pendaftaran Anda akan ditinjau oleh pengurus koperasi. Selama menunggu, status keanggotaan Anda tertulis "Menunggu Persetujuan" dan sebagian fitur belum bisa diakses.',
      'Setelah disetujui pengurus, Simpanan Pokok Anda otomatis tercatat dan seluruh fitur aplikasi bisa langsung digunakan — cukup masuk (login) dengan NIK & password yang sudah dibuat.',
      'Lupa password? Hubungi pengurus/admin koperasi untuk direset — Anda akan mendapat password sementara yang wajib diganti setelah login pertama.',
    ],
  ),
  _PanduanModul(
    icon: Icons.home_outlined,
    judul: 'Beranda',
    ringkasan: 'Ringkasan kondisi keanggotaan Anda begitu membuka aplikasi.',
    poin: [
      'Kartu "Transparansi" menampilkan ringkasan saldo simpanan, pinjaman aktif, dan informasi keanggotaan Anda secara langsung dari sistem koperasi.',
      'Bagian "Pengumuman" menampilkan info terbaru dari pengurus koperasi — ketuk salah satu untuk langsung dibawa ke menu terkait.',
      'Bagian "Produk Terbaru" menampilkan barang terbaru di Katalog koperasi.',
      'Gunakan navigasi di bagian bawah layar (Beranda, Simpan Pinjam, Katalog, E-RAT) untuk berpindah antar layanan utama.',
    ],
  ),
  _PanduanModul(
    icon: Icons.savings_outlined,
    judul: 'Simpanan',
    ringkasan: 'Kelola simpanan Anda: Wajib (otomatis), Sukarela, Sukarela Rutin, dan Berjangka (deposito).',
    poin: [
      'Simpanan Pokok & Wajib dikelola otomatis oleh koperasi (potong gaji) — Anda cukup memantau saldonya, tidak perlu mengajukan apa-apa.',
      'Simpanan Sukarela — ajukan Setor atau Tarik kapan saja. Untuk Setor, Anda WAJIB melampirkan foto/PDF bukti transfer saat mengajukan; pengurus akan meninjau dan menyetujuinya.',
      'Sukarela Rutin — mode menabung otomatis bulanan. Tentukan nominal & tanggal setor tiap bulan, lalu ajukan; setelah disetujui pengurus, sistem akan menyetor otomatis tiap bulan tanpa perlu mengajukan ulang. Ingin berhenti? Ajukan "Berhenti" dan tunggu persetujuan pengurus.',
      'Simpanan Berjangka (deposito) — pilih salah satu paket (nominal + tenor) yang disediakan koperasi, lampirkan bukti transfer, lalu ajukan. Setelah jatuh tempo, Anda bisa mencairkannya untuk menerima pokok + bunga (dipotong pajak). Mencairkan LEBIH CEPAT dari jatuh tempo membuat bunga hangus — Anda hanya menerima pokok.',
    ],
  ),
  _PanduanModul(
    icon: Icons.account_balance_wallet_outlined,
    judul: 'Pinjaman',
    ringkasan: 'Alur pengajuan pinjaman melalui tahap Draft dan surat rekomendasi SDM sebelum diproses pengurus.',
    poin: [
      'Isi nominal & tenor pinjaman yang diinginkan lalu simpan sebagai Draft.',
      'Cetak/unduh draft tersebut dari aplikasi, lalu bawa ke bagian SDM di kantor Anda untuk meminta surat rekomendasi (proses ini dilakukan di luar aplikasi).',
      'Setelah mendapat surat rekomendasi dari SDM, unggah foto/PDF surat itu lewat aplikasi — status pengajuan Anda berubah menjadi "Diajukan" dan mulai ditinjau pengurus koperasi.',
      'Setelah disetujui pengurus, dana otomatis cair dan jadwal angsuran bulanan langsung terbentuk.',
      'Bayar angsuran reguler tiap bulan, atau ajukan Pelunasan Dipercepat (Anda hanya perlu membayar sisa pokok, jasa sisa dibebaskan) — kedua jenis pembayaran ini WAJIB melampirkan bukti transfer saat mengajukan.',
    ],
  ),
  _PanduanModul(
    icon: Icons.storefront_outlined,
    judul: 'Katalog',
    ringkasan: 'Toko koperasi — belanja produk koperasi atau titip barang Anda sendiri untuk dijual.',
    poin: [
      'Pilih produk di Katalog, lalu beli dengan metode Tunai (bayar langsung) atau Kredit (potong gaji, dicicil lewat Tagihan Kredit).',
      'Ingin menjual barang lewat katalog koperasi? Ajukan "Titip Barang" — pengurus akan meninjau sebelum barang Anda tayang di katalog.',
      'Pantau riwayat belanja dan status Tagihan Kredit Anda di menu Akun.',
    ],
  ),
  _PanduanModul(
    icon: Icons.how_to_vote_outlined,
    judul: 'E-RAT (Rapat Anggota Tahunan)',
    ringkasan: 'Ikuti Rapat Anggota Tahunan koperasi secara digital, kapan saja dan di mana saja.',
    poin: [
      'Tab Voting — berikan suara Anda untuk agenda yang sedang dibuka pengurus (misalnya pemilihan pengurus atau persetujuan program kerja).',
      'Tab Dokumen — unduh arsip dokumen resmi RAT (laporan tahunan, dll).',
      'Tab Laporan RAT — baca laporan RAT tahun berjalan begitu ditayangkan pengurus: kondisi keuangan koperasi, kegiatan, dan pembagian SHU tahun itu.',
    ],
  ),
  _PanduanModul(
    icon: Icons.person_outline,
    judul: 'Akun Saya',
    ringkasan: 'Kelola data pribadi dan keamanan akun Anda.',
    poin: [
      'Ubah foto profil, email, dan nomor telepon lewat menu Akun.',
      'Ganti password secara berkala demi keamanan akun Anda.',
      'Lihat ringkasan status keanggotaan dan riwayat aktivitas Anda di koperasi.',
    ],
  ),
];

class PanduanAnggotaPage extends StatefulWidget {
  const PanduanAnggotaPage({super.key});

  @override
  State<PanduanAnggotaPage> createState() => _PanduanAnggotaPageState();
}

class _PanduanAnggotaPageState extends State<PanduanAnggotaPage> {
  bool _mengunduh = false;
  int? _terbuka = 0;

  Future<void> _unduhManualBook() async {
    setState(() => _mengunduh = true);
    try {
      await AuthService().downloadAndOpenManualBookAnggota();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _mengunduh = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KkcsColors.background,
      appBar: AppBar(title: const Text('Panduan Anggota')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Pelajari cara menggunakan aplikasi KKCS, mulai dari pendaftaran sampai mengajukan pinjaman.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: KkcsColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _mengunduh ? null : _unduhManualBook,
              icon: _mengunduh
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_outlined),
              label: Text(_mengunduh ? 'Mengunduh...' : 'Unduh Manual Book (PDF)'),
              style: FilledButton.styleFrom(
                backgroundColor: KkcsColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < _panduanAnggotaModules.length; i++) ...[
            _PanduanModulCard(
              modul: _panduanAnggotaModules[i],
              terbuka: _terbuka == i,
              onTap: () => setState(() => _terbuka = _terbuka == i ? null : i),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PanduanModulCard extends StatelessWidget {
  const _PanduanModulCard({required this.modul, required this.terbuka, required this.onTap});

  final _PanduanModul modul;
  final bool terbuka;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KkcsColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KkcsColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: KkcsColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                    child: Icon(modul.icon, color: KkcsColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(modul.judul, style: const TextStyle(fontWeight: FontWeight.w800, color: KkcsColors.textPrimary, fontSize: 14.5)),
                        const SizedBox(height: 2),
                        Text(modul.ringkasan, style: const TextStyle(color: KkcsColors.textSecondary, fontSize: 12, height: 1.3)),
                      ],
                    ),
                  ),
                  Icon(terbuka ? Icons.expand_less : Icons.expand_more, color: KkcsColors.textMuted),
                ],
              ),
            ),
          ),
          if (terbuka)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final p in modul.poin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Icon(Icons.circle, size: 5, color: KkcsColors.primary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(p, style: const TextStyle(fontSize: 12.5, height: 1.4, color: KkcsColors.textPrimary))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ServiceShell extends StatelessWidget {
  const _ServiceShell({required this.auth, required this.session, required this.selectedIndex, required this.child});

  final AuthService auth;
  final AuthSession session;
  final int selectedIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          if (index == 0) {
            Navigator.pop(context);
            return;
          }
          if (index == selectedIndex) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => _ServiceShell(
                auth: auth,
                session: session,
                selectedIndex: index,
                child: _servicePage(index),
              ),
            ),
          );
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Simpan Pinjam'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Katalog'),
          NavigationDestination(icon: Icon(Icons.how_to_vote_outlined), label: 'E-RAT'),
        ],
      ),
    );
  }

  Widget _servicePage(int index) {
    return switch (index) {
      1 => DigitalSavingsLoanPage(session: session),
      2 => BusinessUnitPage(session: session),
      3 => EratPage(session: session),
      _ => AccountPage(auth: auth, session: session),
    };
  }
}

class _TransparencyDashboard extends StatelessWidget {
  const _TransparencyDashboard({required this.session, required this.summary, required this.loading, required this.error, required this.onRefresh});

  final AuthSession session;
  final HomeSummary? summary;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  String _value(double? amount) => amount == null ? '—' : formatRupiah(amount);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final s = summary;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: KkcsColors.heroGradient,
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white.withValues(alpha: .2)),
                  ),
                  child: const Icon(Icons.visibility_outlined, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Portal Mandiri Anggota',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Dashboard transparansi keanggotaan Anda',
                        style: TextStyle(color: Colors.white.withValues(alpha: .88), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: loading ? null : () => onRefresh(),
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                  tooltip: 'Muat ulang',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_outlined, size: 18, color: KkcsColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Ringkasan keuangan',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: KkcsColors.primaryDeep),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (loading) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator(minHeight: 2.5)),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.error)),
                  ),
                Row(children: [
                  Expanded(
                    child: _DashboardMetric(
                      icon: Icons.savings_outlined,
                      label: 'Total simpanan',
                      value: _value(s?.totalSimpanan),
                      accentColor: KkcsColors.success,
                      accentBg: KkcsColors.successBg,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DetailSimpananPage(session: session)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DashboardMetric(
                      icon: Icons.request_quote_outlined,
                      label: 'Pinjaman aktif',
                      value: s == null ? '—' : (s.jumlahPinjamanAktif == 0 ? 'Tidak ada' : '${formatRupiah(s.sisaPokokPinjaman)} sisa'),
                      accentColor: KkcsColors.warning,
                      accentBg: KkcsColors.warningBg,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DetailPinjamanAktifPage(session: session)),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _DashboardMetric(
                      icon: Icons.payments_outlined,
                      label: 'Cicilan berjalan',
                      value: s == null ? '—' : (s.cicilanBulananBerjalan == 0 ? 'Tidak ada' : '${formatRupiah(s.cicilanBulananBerjalan)} / bln'),
                      accentColor: KkcsColors.primary,
                      accentBg: KkcsColors.primaryLight,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DetailCicilanPage(session: session)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DashboardMetric(
                      icon: Icons.auto_graph_outlined,
                      label: s?.estimasiShuTahun == null ? 'Estimasi SHU' : 'Estimasi SHU ${s!.estimasiShuTahun}',
                      value: s?.estimasiShuNominal == null ? 'Belum tersedia' : formatRupiah(s!.estimasiShuNominal!),
                      accentColor: const Color(0xFF6366F1),
                      accentBg: const Color(0xFFEEF2FF),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ShuSayaPage(session: session)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAnnouncementCard extends StatelessWidget {
  const _HomeAnnouncementCard({required this.items, required this.onOpen});

  final List<Announcement> items;
  final void Function(String tautan) onOpen;

  IconData _icon(String ikon) => switch (ikon) {
        'vote' => Icons.how_to_vote_outlined,
        'dokumen' => Icons.picture_as_pdf_outlined,
        'produk' => Icons.storefront_outlined,
        _ => Icons.campaign_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: KkcsColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.campaign_rounded, size: 18, color: KkcsColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pengumuman', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: KkcsColors.primaryDeep)),
                  const SizedBox(height: 1),
                  Text('Informasi penting dan agenda koperasi', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: KkcsColors.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
            if (items.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: KkcsColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length} baru',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: KkcsColors.primary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KkcsColors.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.notifications_none_rounded, size: 20, color: KkcsColors.textSecondary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Belum ada pengumuman.',
                    style: TextStyle(color: KkcsColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          )
        else
          ...items.map((a) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KkcsColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: a.tautan.isEmpty ? null : () => onOpen(a.tautan),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: KkcsColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_icon(a.ikon), color: KkcsColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.judul, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: KkcsColors.primaryDeep)),
                                const SizedBox(height: 4),
                                Text(a.isi, style: const TextStyle(fontSize: 12, color: KkcsColors.textSecondary, height: 1.35)),
                              ],
                            ),
                          ),
                          if (a.tautan.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: KkcsColors.primaryLight.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.chevron_right, size: 16, color: KkcsColors.primary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              )),
      ],
    );
  }
}

class _LatestProductsPreview extends StatelessWidget {
  const _LatestProductsPreview({required this.products, required this.onOpenCatalog});

  final List<CatalogProduct> products;
  final VoidCallback onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: KkcsColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.storefront_outlined, size: 18, color: KkcsColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Produk terbaru', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: KkcsColors.primaryDeep)),
                  const SizedBox(height: 1),
                  Text('Katalog unit usaha koperasi', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: KkcsColors.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onOpenCatalog,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Text('Buka katalog', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: KkcsColors.primary)),
              label: const Icon(Icons.arrow_forward_rounded, size: 14, color: KkcsColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (products.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KkcsColors.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storefront_outlined, size: 20, color: KkcsColors.textSecondary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Belum ada produk di katalog.',
                    style: TextStyle(color: KkcsColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          )
        else
          ...products.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KkcsColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onOpenCatalog,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 52,
                              height: 52,
                              color: const Color(0xFFF1F5F9),
                              child: p.fotoUrl == null
                                  ? Container(
                                      color: KkcsColors.primaryLight,
                                      child: const Icon(Icons.shopping_bag_outlined, color: KkcsColors.primary, size: 24),
                                    )
                                  : Image.network(
                                      '${AuthService.baseUrl}${p.fotoUrl}',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: KkcsColors.primaryLight,
                                        child: const Icon(Icons.image_not_supported_outlined, color: KkcsColors.primary, size: 22),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.nama,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: KkcsColors.primaryDeep),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: p.sewa ? const Color(0xFFEFF6FF) : KkcsColors.successBg,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        p.sewa ? 'Sewa' : 'Jual',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: p.sewa ? const Color(0xFF2563EB) : KkcsColors.success,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        p.sewa
                                            ? (p.sumber == 'TitipanAnggota' ? 'Titipan Anggota' : 'Unit Koperasi')
                                            : (p.stok > 0 ? 'Stok ${p.stok.toStringAsFixed(p.stok % 1 == 0 ? 0 : 2)} ${p.satuan}' : 'Stok habis'),
                                        style: const TextStyle(fontSize: 11, color: KkcsColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${formatRupiah(p.harga)}${p.sewa ? '/${p.satuan}' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: KkcsColors.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
      ],
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.accentColor,
    this.accentBg,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accentColor;
  final Color? accentBg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? KkcsColors.primary;
    final bg = accentBg ?? KkcsColors.primaryLight;

    final content = Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KkcsColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              if (onTap != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: KkcsColors.border),
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: KkcsColors.primary),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: KkcsColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: KkcsColors.primaryDeep),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: content);
  }
}

// ── DETAIL TOTAL SIMPANAN ──────────────────────────────────────────────────
class DetailSimpananPage extends StatefulWidget {
  const DetailSimpananPage({required this.session, super.key});

  final AuthSession session;

  @override
  State<DetailSimpananPage> createState() => _DetailSimpananPageState();
}

class _DetailSimpananPageState extends State<DetailSimpananPage> {
  bool _loading = true;
  String? _error;
  SavingsOverview? _overview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AuthService().fetchSavings();
      if (!mounted) return;
      setState(() => _overview = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : 'Gagal memuat rincian simpanan.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _categoryCard({
    required IconData icon,
    required String title,
    required String badge,
    required String subtitle,
    required double amount,
    String? extraInfo,
    Color? accentColor,
    Color? accentBg,
  }) {
    final color = accentColor ?? KkcsColors.primary;
    final bg = accentBg ?? KkcsColors.primaryLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KkcsColors.border),
        boxShadow: [
          BoxShadow(
            color: KkcsColors.primaryDeep.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: KkcsColors.primaryDeep,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.5, color: KkcsColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: KkcsColors.borderLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Saldo Simpanan',
                  style: TextStyle(fontSize: 12, color: KkcsColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                Text(
                  formatRupiah(amount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: KkcsColors.primaryDeep,
                  ),
                ),
              ],
            ),
          ),
          if (extraInfo != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: KkcsColors.textDisabled),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    extraInfo,
                    style: const TextStyle(fontSize: 11, color: KkcsColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = _overview;
    final totalBerjangka = o == null
        ? 0.0
        : o.berjangka.milikSaya.fold<double>(0.0, (acc, item) => acc + item.nominal);
    final totalSimpanan = o == null
        ? 0.0
        : (o.pokok.saldo + o.wajib.saldo + o.sukarela.saldo + totalBerjangka);

    return Scaffold(
      backgroundColor: KkcsColors.background,
      appBar: AppBar(
        title: const Text('Rincian Total Simpanan'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ErrorMessage(message: _error),
                      ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: KkcsColors.heroGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: KkcsColors.primaryDeep.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.shield_outlined, size: 13, color: Color(0xFFA5F3FC)),
                                    SizedBox(width: 5),
                                    Text(
                                      'Akumulasi Simpanan',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: KkcsColors.successBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Aktif',
                                  style: TextStyle(color: KkcsColors.success, fontSize: 10.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'TOTAL SALDO SIMPANAN',
                            style: TextStyle(
                              color: Color(0xFFA5F3FC),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatRupiah(totalSimpanan),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tercatat atas nama ${widget.session.user.namaLengkap} (${widget.session.user.nomorIndukKaryawan})',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Row(
                      children: [
                        Icon(Icons.pie_chart_outline_rounded, size: 18, color: KkcsColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Kategori Akun Simpanan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: KkcsColors.primaryDeep,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (o != null) ...[
                      _categoryCard(
                        icon: Icons.account_balance_rounded,
                        title: 'Simpanan Pokok',
                        badge: 'Wajib Awal',
                        subtitle: 'Simpanan pokok keanggotaan koperasi pertama kali',
                        amount: o.pokok.saldo,
                        extraInfo: o.pokok.nomorRekening != null ? 'No. Rekening: ${o.pokok.nomorRekening}' : 'Terdaftar resmi',
                        accentColor: KkcsColors.primary,
                        accentBg: KkcsColors.primaryLight,
                      ),
                      _categoryCard(
                        icon: Icons.calendar_month_rounded,
                        title: 'Simpanan Wajib',
                        badge: 'Rutin Bulanan',
                        subtitle: 'Iuran wajib yang disetorkan tiap bulan keanggotaan',
                        amount: o.wajib.saldo,
                        extraInfo: o.wajib.tagihan.any((t) => t.status != 'Dibayar' && t.status != 'Lunas')
                            ? '${o.wajib.tagihan.where((t) => t.status != 'Dibayar' && t.status != 'Lunas').length} tagihan belum terbayar'
                            : 'Semua tagihan wajib lunas',
                        accentColor: KkcsColors.success,
                        accentBg: KkcsColors.successBg,
                      ),
                      _categoryCard(
                        icon: Icons.wallet_rounded,
                        title: 'Simpanan Sukarela',
                        badge: 'Fleksibel',
                        subtitle: 'Tabungan fleksibel yang dapat disetor atau ditarik',
                        amount: o.sukarela.saldo,
                        extraInfo: 'Dapat disetor atau dicairkan di menu Simpan Pinjam',
                        accentColor: const Color(0xFF0284C7),
                        accentBg: const Color(0xFFF0F9FF),
                      ),
                      _categoryCard(
                        icon: Icons.lock_clock_rounded,
                        title: 'Simpanan Berjangka',
                        badge: 'Investasi',
                        subtitle: 'Simpanan berjangka dengan bagi hasil kompetitif',
                        amount: totalBerjangka,
                        extraInfo: '${o.berjangka.milikSaya.length} penempatan bilyet terdaftar',
                        accentColor: const Color(0xFF6366F1),
                        accentBg: const Color(0xFFEEF2FF),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Icon(Icons.history_rounded, size: 18, color: KkcsColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Riwayat Mutasi Terakhir',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: KkcsColors.primaryDeep,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (o == null || o.mutasi.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: KkcsColors.border),
                        ),
                        child: const Center(
                          child: Text(
                            'Belum ada riwayat mutasi transaksi.',
                            style: TextStyle(color: KkcsColors.textSecondary, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ...o.mutasi.map((m) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: KkcsColors.borderLight),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: m.jenis == 'Setor' ? KkcsColors.successBg : KkcsColors.dangerBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    m.jenis == 'Setor' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                    size: 16,
                                    color: m.jenis == 'Setor' ? KkcsColors.success : KkcsColors.danger,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.keterangan ?? (m.jenis == 'Setor' ? 'Setoran Simpanan' : 'Penarikan Simpanan'),
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.primaryDeep),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _monthLabel(m.tanggal),
                                        style: const TextStyle(fontSize: 11, color: KkcsColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      (m.jenis == 'Setor' ? '+ ' : '- ') + formatRupiah(m.nominal),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: m.jenis == 'Setor' ? KkcsColors.success : KkcsColors.danger,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Saldo: ${formatRupiah(m.saldoSetelah)}',
                                      style: const TextStyle(fontSize: 10.5, color: KkcsColors.textMuted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── DETAIL PINJAMAN AKTIF ──────────────────────────────────────────────────
class DetailPinjamanAktifPage extends StatefulWidget {
  const DetailPinjamanAktifPage({required this.session, super.key});

  final AuthSession session;

  @override
  State<DetailPinjamanAktifPage> createState() => _DetailPinjamanAktifPageState();
}

class _DetailPinjamanAktifPageState extends State<DetailPinjamanAktifPage> {
  bool _loading = true;
  String? _error;
  LoanOverview? _overview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AuthService().fetchMyLoans();
      if (!mounted) return;
      setState(() => _overview = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : 'Gagal memuat rincian pinjaman.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _overview;
    final pinjamanAktif = o?.pinjaman.where((p) => !p.lunas).toList() ?? const <Loan>[];
    final totalSisaPokok = pinjamanAktif.fold<double>(0.0, (acc, item) => acc + item.sisaPokok);

    return Scaffold(
      backgroundColor: KkcsColors.background,
      appBar: AppBar(
        title: const Text('Detail Pinjaman Aktif'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ErrorMessage(message: _error),
                      ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF083344), Color(0xFF0E7490), Color(0xFF155E75)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: KkcsColors.primaryDeep.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.request_quote_outlined, size: 13, color: Color(0xFFFDE68A)),
                                    SizedBox(width: 5),
                                    Text(
                                      'Fasilitas Pinjaman',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: pinjamanAktif.isEmpty ? KkcsColors.successBg : KkcsColors.warningBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${pinjamanAktif.length} Fasilitas Aktif',
                                  style: TextStyle(
                                    color: pinjamanAktif.isEmpty ? KkcsColors.success : KkcsColors.warning,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'TOTAL SISA POKOK PINJAMAN',
                            style: TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatRupiah(totalSisaPokok),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            pinjamanAktif.isEmpty
                                ? 'Tidak ada kewajiban pinjaman yang sedang berjalan.'
                                : 'Kewajiban aktif yang tercatat atas nama Anda di koperasi.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (pinjamanAktif.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: KkcsColors.border),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: KkcsColors.successBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle_outline_rounded, size: 42, color: KkcsColors.success),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tidak Ada Pinjaman Aktif',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: KkcsColors.primaryDeep),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Anda tidak memiliki pinjaman berjalan saat ini. Pengajuan pinjaman baru dapat dilakukan melalui tab Pinjaman pada menu Simpan Pinjam.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: KkcsColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                      )
                    else
                      ...pinjamanAktif.map((loan) {
                        final progress = loan.tenorBulan > 0
                            ? (loan.angsuranTerbayar / loan.tenorBulan).clamp(0.0, 1.0)
                            : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: KkcsColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: KkcsColors.primaryDeep.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: KkcsColors.primaryLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.receipt_long_rounded, size: 18, color: KkcsColors.primary),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          loan.nomorPinjaman,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: KkcsColors.primaryDeep),
                                        ),
                                        Text(
                                          'Tenor ${loan.tenorBulan} bulan',
                                          style: const TextStyle(fontSize: 11.5, color: KkcsColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusBadge(status: loan.status),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Kemajuan Angsuran',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: KkcsColors.textSecondary),
                                      ),
                                      Text(
                                        '${loan.angsuranTerbayar}/${loan.tenorBulan} bln (${(progress * 100).toStringAsFixed(0)}%)',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: KkcsColors.primary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 7,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      valueColor: const AlwaysStoppedAnimation<Color>(KkcsColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: KkcsColors.borderLight),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Plafon Pinjaman Awal', style: TextStyle(fontSize: 12, color: KkcsColors.textSecondary)),
                                        Text(formatRupiah(loan.pokok), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: KkcsColors.primaryDeep)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Sisa Pokok Pinjaman', style: TextStyle(fontSize: 12, color: KkcsColors.textSecondary)),
                                        Text(formatRupiah(loan.sisaPokok), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: KkcsColors.danger)),
                                      ],
                                    ),
                                    const Divider(height: 14, color: KkcsColors.borderLight),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Angsuran per Bulan', style: TextStyle(fontSize: 12, color: KkcsColors.textSecondary)),
                                        Text('${formatRupiah(loan.angsuranPerBulan)} / bln', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: KkcsColors.primary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.stars_rounded, size: 16, color: KkcsColors.success),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Pelunasan Dipercepat',
                                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: KkcsColors.success),
                                          ),
                                          Text(
                                            'Nilai: ${formatRupiah(loan.nilaiPelunasanDipercepat)} (Hemat jasa ${formatRupiah(loan.jasaDibebaskan)})',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── DETAIL CICILAN BERJALAN ──────────────────────────────────────────────────
class DetailCicilanPage extends StatefulWidget {
  const DetailCicilanPage({required this.session, super.key});

  final AuthSession session;

  @override
  State<DetailCicilanPage> createState() => _DetailCicilanPageState();
}

class _DetailCicilanPageState extends State<DetailCicilanPage> {
  bool _loading = true;
  String? _error;
  LoanOverview? _overview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AuthService().fetchMyLoans();
      if (!mounted) return;
      setState(() => _overview = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : 'Gagal memuat rincian cicilan.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _overview;
    final pinjamanAktif = o?.pinjaman.where((p) => !p.lunas).toList() ?? const <Loan>[];
    final totalCicilanBulanan = pinjamanAktif.fold<double>(0.0, (acc, item) => acc + item.angsuranPerBulan);
    final totalSisaAngsuran = pinjamanAktif.fold<int>(0, (acc, item) => acc + item.sisaAngsuran);

    return Scaffold(
      backgroundColor: KkcsColors.background,
      appBar: AppBar(
        title: const Text('Detail Cicilan Berjalan'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ErrorMessage(message: _error),
                      ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0891B2), Color(0xFF0284C7), Color(0xFF0369A1)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: KkcsColors.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.payments_outlined, size: 13, color: Colors.white),
                                    SizedBox(width: 5),
                                    Text(
                                      'Cicilan Bulanan',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$totalSisaAngsuran Bulan Sisa',
                                  style: const TextStyle(color: KkcsColors.primaryDeep, fontSize: 10.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'TOTAL CICILAN PER BULAN',
                            style: TextStyle(
                              color: Color(0xFFCFFAFE),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatRupiah(totalCicilanBulanan)} / bln',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            pinjamanAktif.isEmpty
                                ? 'Tidak ada kewajiban cicilan yang harus dibayarkan.'
                                : 'Total pemotongan gaji / setoran angsuran pinjaman bulanan.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 18, color: KkcsColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Daftar Cicilan Pinjaman Aktif',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: KkcsColors.primaryDeep,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (pinjamanAktif.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: KkcsColors.border),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: KkcsColors.successBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle_outline_rounded, size: 42, color: KkcsColors.success),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tidak Ada Cicilan Berjalan',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: KkcsColors.primaryDeep),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Anda tidak memiliki tanggungan cicilan pinjaman bulanan saat ini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: KkcsColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                      )
                    else
                      ...pinjamanAktif.map((loan) {
                        final angsuranTertunda = loan.angsuran.where((a) => a.status != 'Lunas').toList();
                        final angsuranBerikutnya = angsuranTertunda.isNotEmpty ? angsuranTertunda.first : null;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: KkcsColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: KkcsColors.primaryDeep.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      loan.nomorPinjaman,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: KkcsColors.primaryDeep),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: KkcsColors.primaryLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Sisa ${loan.sisaAngsuran} bln',
                                      style: const TextStyle(color: KkcsColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: KkcsColors.borderLight),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Pokok Angsuran', style: TextStyle(fontSize: 12, color: KkcsColors.textSecondary)),
                                        Text(formatRupiah(loan.pokokPerBulan), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: KkcsColors.primaryDeep)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Jasa Koperasi', style: TextStyle(fontSize: 12, color: KkcsColors.textSecondary)),
                                        Text(formatRupiah(loan.jasaPerBulan), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: KkcsColors.primaryDeep)),
                                      ],
                                    ),
                                    const Divider(height: 14, color: KkcsColors.borderLight),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Total Tagihan per Bulan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: KkcsColors.primaryDeep)),
                                        Text(formatRupiah(loan.angsuranPerBulan), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: KkcsColors.primary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (angsuranBerikutnya != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFFD97706)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Angsuran ke-${angsuranBerikutnya.angsuranKe} jatuh tempo: ${_monthLabel(angsuranBerikutnya.jatuhTempo)}',
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
        ),
      ),
    );
  }
}

class ShuSayaPage extends StatefulWidget {
  const ShuSayaPage({required this.session, super.key});

  final AuthSession session;

  @override
  State<ShuSayaPage> createState() => _ShuSayaPageState();
}

class _ShuSayaPageState extends State<ShuSayaPage> {
  bool _loading = true;
  String? _error;
  List<ShuHistoryEntry> _riwayat = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AuthService().fetchMyShu();
      if (!mounted) return;
      setState(() => _riwayat = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : 'Gagal memuat data SHU.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KkcsColors.background,
      appBar: AppBar(
        title: const Text('SHU Saya'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang data',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ErrorMessage(message: _error),
                      ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFECFEFF), Color(0xFFF0FDFA)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF99F6E4), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF99F6E4)),
                                ),
                                child: const Icon(Icons.auto_graph_rounded, size: 18, color: KkcsColors.primaryDark),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Sisa Hasil Usaha (SHU)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: KkcsColors.primaryDeep,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF99F6E4)),
                                ),
                                child: const Text(
                                  'Dividen Anggota',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: KkcsColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Sisa Hasil Usaha (SHU) adalah bagian keuntungan koperasi yang dibagikan secara adil kepada setiap anggota aktif. '
                            'Nominal dihitung dari jasa modal (simpanan pokok & wajib) dan jasa usaha (transaksi belanja & pinjaman) Anda sepanjang tahun buku.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: KkcsColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_riwayat.isEmpty && !_loading)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: KkcsColors.border),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: KkcsColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.query_stats_rounded, size: 42, color: KkcsColors.primary),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum Ada SHU yang Difinalisasi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: KkcsColors.primaryDeep,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Estimasi dan pembagian SHU akan otomatis muncul di sini setelah pengurus menyelesaikan tutup buku dan disahkan pada Rapat Anggota Tahunan (RAT).',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: KkcsColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._riwayat.asMap().entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _ShuYearCard(data: entry.value, highlighted: entry.key == 0),
                          )),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ShuYearCard extends StatelessWidget {
  const _ShuYearCard({required this.data, required this.highlighted});

  final ShuHistoryEntry data;
  final bool highlighted;

  Widget _calcRow({
    required String label,
    required double value,
    String? subtitle,
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: bold ? 13.5 : 12.5,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: bold ? KkcsColors.primaryDeep : KkcsColors.textSecondary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10.5, color: KkcsColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          Text(
            (value < 0 ? '- ' : '') + formatRupiah(value.abs()),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              fontSize: bold ? 14 : 13,
              color: color ?? (bold ? KkcsColors.primaryDeep : KkcsColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? KkcsColors.primary : KkcsColors.border,
          width: highlighted ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted ? KkcsColors.primary.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.02),
            blurRadius: highlighted ? 16 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: highlighted ? const Color(0xFFF0FDFA) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              border: Border(
                bottom: BorderSide(
                  color: highlighted ? const Color(0xFFCCFBF1) : KkcsColors.borderLight,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: highlighted ? KkcsColors.primary : KkcsColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tahun Buku ${data.tahun}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: KkcsColors.primaryDeep,
                  ),
                ),
                const Spacer(),
                if (highlighted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: KkcsColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Terbaru',
                          style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Selesai',
                      style: TextStyle(color: KkcsColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFECFEFF), Color(0xFFE0F2FE)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF67E8F9), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified_rounded, size: 14, color: KkcsColors.primary),
                                SizedBox(width: 5),
                                Text(
                                  'SHU DITERIMA (NETO)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: KkcsColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Bersih setelah PPh Final 10%',
                              style: TextStyle(fontSize: 11, color: KkcsColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatRupiah(data.totalShuNeto),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: KkcsColors.primaryDeep,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: KkcsColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.savings_outlined, size: 14, color: KkcsColors.primary),
                                SizedBox(width: 5),
                                Text(
                                  'Dasar Simpanan',
                                  style: TextStyle(fontSize: 11, color: KkcsColors.textSecondary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatRupiah(data.simpananAnggota),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: KkcsColors.primaryDeep),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'Pokok & Wajib',
                              style: TextStyle(fontSize: 10, color: KkcsColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: KkcsColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.shopping_bag_outlined, size: 14, color: Color(0xFF6366F1)),
                                SizedBox(width: 5),
                                Text(
                                  'Dasar Transaksi',
                                  style: TextStyle(fontSize: 11, color: KkcsColors.textSecondary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatRupiah(data.transaksiAnggota),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: KkcsColors.primaryDeep),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'Pinjaman & Belanja',
                              style: TextStyle(fontSize: 10, color: KkcsColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: KkcsColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      _calcRow(
                        label: 'Jasa Modal Anggota (JMA)',
                        subtitle: 'Porsi Modal ${(data.persenJasaModal * 100).toStringAsFixed(0)}%',
                        value: data.jma,
                      ),
                      _calcRow(
                        label: 'Jasa Usaha Anggota (JUA)',
                        subtitle: 'Porsi Usaha ${(data.persenJasaUsaha * 100).toStringAsFixed(0)}%',
                        value: data.jua,
                      ),
                      const Divider(height: 16, color: KkcsColors.borderLight),
                      _calcRow(
                        label: 'Total SHU (Bruto)',
                        value: data.totalShu,
                        bold: true,
                      ),
                      _calcRow(
                        label: 'PPh Final (10%)',
                        subtitle: 'Pajak dividen resmi',
                        value: -data.pajak,
                        color: const Color(0xFFD97706),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 13, color: KkcsColors.textDisabled),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Difinalisasi ${_monthLabel(data.difinalisasiPada)} · Skema JMA ${(data.persenJasaModal * 100).toStringAsFixed(0)}% / JUA ${(data.persenJasaUsaha * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 11, color: KkcsColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EratPage extends StatefulWidget {
  const EratPage({required this.session, super.key});

  final AuthSession session;

  @override
  State<EratPage> createState() => _EratPageState();
}

class EratOption {
  const EratOption({required this.id, required this.label, required this.jumlah});
  final int id;
  final String label;
  final int jumlah;
  factory EratOption.fromJson(Map<String, dynamic> json) =>
      EratOption(id: json['id'] as int, label: json['label'] as String, jumlah: json['jumlah'] as int);
}

class EratAgendaItem {
  const EratAgendaItem({
    required this.id,
    required this.judul,
    this.deskripsi,
    required this.status,
    required this.totalSuara,
    this.pilihanSaya,
    required this.opsi,
  });

  final int id;
  final String judul;
  final String? deskripsi;
  final String status; // Aktif | Selesai
  final int totalSuara;
  final int? pilihanSaya;
  final List<EratOption> opsi;

  bool get sudahMemilih => pilihanSaya != null;
  bool get tampilkanHasil => sudahMemilih || status == 'Selesai';

  factory EratAgendaItem.fromJson(Map<String, dynamic> json) => EratAgendaItem(
        id: json['id'] as int,
        judul: json['judul'] as String,
        deskripsi: json['deskripsi'] as String?,
        status: json['status'] as String,
        totalSuara: json['totalSuara'] as int,
        pilihanSaya: json['pilihanSaya'] as int?,
        opsi: (json['opsi'] as List<dynamic>).map((e) => EratOption.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class RatDocument {
  const RatDocument({required this.id, required this.tahun, required this.judul, this.deskripsi, required this.fileUrl, required this.diterbitkanPada});
  final int id;
  final int tahun;
  final String judul;
  final String? deskripsi;
  final String fileUrl;
  final DateTime diterbitkanPada;
  factory RatDocument.fromJson(Map<String, dynamic> json) => RatDocument(
        id: json['id'] as int,
        tahun: json['tahun'] as int,
        judul: json['judul'] as String,
        deskripsi: json['deskripsi'] as String?,
        fileUrl: json['fileUrl'] as String,
        diterbitkanPada: DateTime.parse(json['diterbitkanPada'] as String),
      );
}

class LaporanRatShu {
  const LaporanRatShu({
    required this.totalShu, required this.totalPajak, required this.totalShuNeto,
    required this.persenAnggota, required this.persenJasaModal, required this.persenJasaUsaha, required this.persenPengurus, required this.persenCadangan,
    required this.jasaPengurusPool, required this.cadanganAmount, required this.jumlahAnggota,
  });
  final double totalShu;
  final double totalPajak;
  final double totalShuNeto;
  final double persenAnggota;
  final double persenJasaModal;
  final double persenJasaUsaha;
  final double persenPengurus;
  final double persenCadangan;
  final double jasaPengurusPool;
  final double cadanganAmount;
  final int jumlahAnggota;
  factory LaporanRatShu.fromJson(Map<String, dynamic> json) => LaporanRatShu(
        totalShu: (json['totalShu'] as num).toDouble(),
        totalPajak: (json['totalPajak'] as num).toDouble(),
        totalShuNeto: (json['totalShuNeto'] as num).toDouble(),
        persenAnggota: (json['persenAnggota'] as num).toDouble(),
        persenJasaModal: (json['persenJasaModal'] as num).toDouble(),
        persenJasaUsaha: (json['persenJasaUsaha'] as num).toDouble(),
        persenPengurus: (json['persenPengurus'] as num).toDouble(),
        persenCadangan: (json['persenCadangan'] as num).toDouble(),
        jasaPengurusPool: (json['jasaPengurusPool'] as num).toDouble(),
        cadanganAmount: (json['cadanganAmount'] as num).toDouble(),
        jumlahAnggota: json['jumlahAnggota'] as int,
      );
}

class LaporanRatTahunan {
  const LaporanRatTahunan({
    required this.tahun,
    required this.visi, required this.misi, required this.alamatKantor,
    required this.kegiatanBisnis, required this.kegiatanSosial,
    required this.rencanaBisnisTahunDepan, required this.rencanaSosialTahunDepan, required this.catatanTambahan,
    required this.totalAnggotaAktifSaatIni, required this.anggotaBaruTahunIni, required this.totalAnggotaNonaktifSaatIni,
    required this.totalAset, required this.totalLiabilitas, required this.totalEkuitas,
    required this.totalPendapatan, required this.totalBeban, required this.labaBersih,
    required this.shu,
    required this.rabTotalPendapatan, required this.rabTotalBeban,
  });
  final int tahun;
  final String visi;
  final String misi;
  final String? alamatKantor;
  final String? kegiatanBisnis;
  final String? kegiatanSosial;
  final String? rencanaBisnisTahunDepan;
  final String? rencanaSosialTahunDepan;
  final String? catatanTambahan;
  final int totalAnggotaAktifSaatIni;
  final int anggotaBaruTahunIni;
  final int totalAnggotaNonaktifSaatIni;
  final double totalAset;
  final double totalLiabilitas;
  final double totalEkuitas;
  final double totalPendapatan;
  final double totalBeban;
  final double labaBersih;
  final LaporanRatShu? shu;
  final double? rabTotalPendapatan;
  final double? rabTotalBeban;

  factory LaporanRatTahunan.fromJson(Map<String, dynamic> json) {
    final profil = json['profil'] as Map<String, dynamic>;
    final konten = json['konten'] as Map<String, dynamic>;
    final neraca = json['neracaAkhirTahun'] as Map<String, dynamic>;
    final labaRugi = json['labaRugi'] as Map<String, dynamic>;
    final shuJson = json['shu'] as Map<String, dynamic>?;
    return LaporanRatTahunan(
      tahun: json['tahun'] as int,
      visi: profil['visi'] as String,
      misi: profil['misi'] as String,
      alamatKantor: profil['alamatKantor'] as String?,
      kegiatanBisnis: konten['kegiatanBisnis'] as String?,
      kegiatanSosial: konten['kegiatanSosial'] as String?,
      rencanaBisnisTahunDepan: konten['rencanaBisnisTahunDepan'] as String?,
      rencanaSosialTahunDepan: konten['rencanaSosialTahunDepan'] as String?,
      catatanTambahan: konten['catatanTambahan'] as String?,
      totalAnggotaAktifSaatIni: json['totalAnggotaAktifSaatIni'] as int,
      anggotaBaruTahunIni: json['anggotaBaruTahunIni'] as int,
      totalAnggotaNonaktifSaatIni: json['totalAnggotaNonaktifSaatIni'] as int,
      totalAset: (neraca['totalAset'] as num).toDouble(),
      totalLiabilitas: (neraca['totalLiabilitas'] as num).toDouble(),
      totalEkuitas: (neraca['totalEkuitas'] as num).toDouble(),
      totalPendapatan: (labaRugi['totalPendapatan'] as num).toDouble(),
      totalBeban: (labaRugi['totalBeban'] as num).toDouble(),
      labaBersih: (labaRugi['labaBersih'] as num).toDouble(),
      shu: shuJson == null ? null : LaporanRatShu.fromJson(shuJson),
      rabTotalPendapatan: (json['rabTotalPendapatan'] as num?)?.toDouble(),
      rabTotalBeban: (json['rabTotalBeban'] as num?)?.toDouble(),
    );
  }
}

class _EratPageState extends State<EratPage> {
  bool _loading = true;
  String? _error;
  int? _busyAgenda;
  List<EratAgendaItem> _agenda = const [];
  List<RatDocument> _dokumen = const [];
  LaporanRatTahunan? _laporanRat;
  final Map<int, int> _pilihan = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final agenda = await AuthService().fetchEratAgenda();
      final dokumen = await AuthService().fetchRatDocuments();
      LaporanRatTahunan? laporanRat;
      try {
        laporanRat = await AuthService().fetchLaporanRatTerbaru();
      } catch (_) {
        // Laporan otomatis opsional — jangan gagalkan seluruh halaman jika endpoint ini bermasalah.
      }
      if (!mounted) return;
      setState(() {
        _agenda = agenda;
        _dokumen = dokumen;
        _laporanRat = laporanRat;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message.replaceFirst('Exception: ', ''))));
  }

  Future<void> _vote(EratAgendaItem agenda) async {
    final opsiId = _pilihan[agenda.id];
    if (opsiId == null) return;
    setState(() => _busyAgenda = agenda.id);
    try {
      await AuthService().submitVote(agendaId: agenda.id, opsiId: opsiId);
      if (!mounted) return;
      _toast('Suara Anda tercatat.');
      await _load();
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _busyAgenda = null);
    }
  }

  Future<void> _openDocument(RatDocument doc) async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/erat/laporan-tahunan/${doc.id}/berkas');
    var opened = false;
    for (final mode in [LaunchMode.externalApplication, LaunchMode.platformDefault, LaunchMode.inAppBrowserView]) {
      try {
        if (await launchUrl(uri, mode: mode)) {
          opened = true;
          break;
        }
      } catch (_) {
        // coba mode berikutnya
      }
    }
    if (!opened && mounted) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Buka dokumen di browser'),
          content: SelectableText('$uri'),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '$uri'));
                Navigator.pop(dialogContext);
                _toast('Tautan disalin.');
              },
              child: const Text('Salin tautan'),
            ),
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Tutup')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partisipasi E-RAT'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Muat ulang')],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rapat Anggota Tahunan Digital',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: KkcsColors.primaryDeep,
                            letterSpacing: -0.3,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gunakan hak suara Anda dan pelajari dokumen pertanggungjawaban koperasi.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: KkcsColors.textSecondary,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              if (_loading) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator(minHeight: 2)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(color: KkcsColors.primary, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Voting',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: KkcsColors.primaryDeep,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!_loading && _agenda.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KkcsColors.borderSubtle),
                  ),
                  child: const Center(
                    child: Text(
                      'Belum ada agenda voting yang ditayangkan.',
                      style: TextStyle(fontSize: 13, color: KkcsColors.textSecondary),
                    ),
                  ),
                ),
              ..._agenda.map(_buildAgendaCard),
              const SizedBox(height: 16),
              if (_laporanRat != null) ...[
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(color: KkcsColors.primary, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Laporan RAT Resmi',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: KkcsColors.primaryDeep,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildLaporanRatCard(_laporanRat!),
                const SizedBox(height: 18),
              ],
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(color: KkcsColors.primary, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Dokumen RAT terkini',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: KkcsColors.primaryDeep,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!_loading && _dokumen.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KkcsColors.borderSubtle),
                  ),
                  child: const Center(
                    child: Text(
                      'Belum ada dokumen RAT diterbitkan.',
                      style: TextStyle(fontSize: 13, color: KkcsColors.textSecondary),
                    ),
                  ),
                ),
              ..._dokumen.asMap().entries.map((entry) => _buildDocumentCard(entry.value, terbaru: entry.key == 0)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgendaCard(EratAgendaItem agenda) {
    final selesai = agenda.status == 'Selesai';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: KkcsColors.borderSubtle, width: 1.2),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selesai ? const Color(0xFFF1F5F9) : KkcsColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    selesai ? Icons.task_alt_outlined : Icons.how_to_vote_outlined,
                    size: 20,
                    color: selesai ? KkcsColors.textSecondary : KkcsColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agenda.judul,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: KkcsColors.textPrimary),
                      ),
                      if (agenda.deskripsi != null && agenda.deskripsi!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          agenda.deskripsi!,
                          style: const TextStyle(fontSize: 12.5, color: KkcsColors.textSecondary, height: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: selesai ? const Color(0xFFF1F5F9) : KkcsColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: selesai ? KkcsColors.borderSubtle : KkcsColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    selesai ? 'Selesai' : 'Berlangsung',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selesai ? KkcsColors.textSecondary : KkcsColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (agenda.tampilkanHasil)
              ...agenda.opsi.map((o) {
                final pct = agenda.totalSuara == 0 ? 0.0 : o.jumlah / agenda.totalSuara;
                final dipilih = agenda.pilihanSaya == o.id;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dipilih ? const Color(0xFFF0FDFA) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: dipilih ? KkcsColors.primary : KkcsColors.borderSubtle,
                      width: dipilih ? 1.4 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    o.label,
                                    style: TextStyle(
                                      fontWeight: dipilih ? FontWeight.w800 : FontWeight.w600,
                                      fontSize: 13,
                                      color: dipilih ? KkcsColors.primaryDeep : KkcsColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (dipilih) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: KkcsColors.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Pilihan Anda', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '${o.jumlah} suara · ${(pct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: dipilih ? KkcsColors.primary : KkcsColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 7,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(dipilih ? KkcsColors.primary : const Color(0xFF0284C7)),
                        ),
                      ),
                    ],
                  ),
                );
              })
            else ...[
              ...agenda.opsi.map((o) {
                final isSelected = _pilihan[agenda.id] == o.id;
                return InkWell(
                  onTap: _busyAgenda == agenda.id ? null : () => setState(() => _pilihan[agenda.id] = o.id),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? KkcsColors.primaryLight : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? KkcsColors.primary : KkcsColors.borderSubtle,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 20,
                          color: isSelected ? KkcsColors.primary : KkcsColors.textDisabled,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            o.label,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                              color: isSelected ? KkcsColors.primaryDeep : KkcsColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: (_pilihan[agenda.id] == null || _busyAgenda == agenda.id) ? null : () => _vote(agenda),
                style: FilledButton.styleFrom(
                  backgroundColor: KkcsColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _busyAgenda == agenda.id
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.how_to_vote_outlined, size: 18),
                label: const Text('Kirim suara', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.people_alt_outlined, size: 14, color: KkcsColors.textDisabled),
                const SizedBox(width: 6),
                Text(
                  '${agenda.totalSuara} suara masuk',
                  style: const TextStyle(fontSize: 11.5, color: KkcsColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(RatDocument doc, {required bool terbaru}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: terbaru ? KkcsColors.primary.withValues(alpha: 0.35) : KkcsColors.borderSubtle,
          width: 1.2,
        ),
      ),
      color: terbaru ? const Color(0xFFF0FDFA) : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: terbaru ? KkcsColors.primaryLight : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.picture_as_pdf_outlined,
            color: terbaru ? KkcsColors.primary : const Color(0xFFEF4444),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                doc.judul,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: KkcsColors.textPrimary),
              ),
            ),
            if (terbaru) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: KkcsColors.primary, borderRadius: BorderRadius.circular(4)),
                child: const Text('Terbaru', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'Tahun ${doc.tahun}${doc.deskripsi != null && doc.deskripsi!.isNotEmpty ? ' · ${doc.deskripsi}' : ''}',
            style: const TextStyle(fontSize: 12, color: KkcsColors.textSecondary),
          ),
        ),
        trailing: const Icon(Icons.open_in_new, size: 18, color: KkcsColors.primary),
        onTap: () => _openDocument(doc),
      ),
    );
  }

  Widget _buildLaporanRatCard(LaporanRatTahunan laporan) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF99F6E4), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LaporanRatDetailPage(laporan: laporan))),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: KkcsColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fact_check_outlined, color: KkcsColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Laporan RAT Tahun Buku ${laporan.tahun}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: KkcsColors.primaryDeep),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: KkcsColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Resmi', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Neraca, Hasil Usaha & SHU otomatis dari sistem${laporan.shu != null ? ' · SHU neto ${formatRupiah(laporan.shu!.totalShuNeto)}' : ''}',
                        style: const TextStyle(fontSize: 12, color: KkcsColors.textSecondary, height: 1.25),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: KkcsColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LaporanRatDetailPage extends StatelessWidget {
  const LaporanRatDetailPage({required this.laporan, super.key});

  final LaporanRatTahunan laporan;

  @override
  Widget build(BuildContext context) {
    final shu = laporan.shu;
    final persenAnggotaEfektif = shu == null
        ? 0.0
        : (shu.persenAnggota > 0 ? shu.persenAnggota : (shu.persenJasaModal + shu.persenJasaUsaha));
    final persenModalEfektif = shu == null || shu.persenAnggota > 0 || persenAnggotaEfektif == 0
        ? (shu?.persenJasaModal ?? 0.0)
        : shu.persenJasaModal / persenAnggotaEfektif;
    final persenUsahaEfektif = shu == null || shu.persenAnggota > 0 || persenAnggotaEfektif == 0
        ? (shu?.persenJasaUsaha ?? 0.0)
        : shu.persenJasaUsaha / persenAnggotaEfektif;
    final anggotaPool = shu == null ? 0.0 : shu.totalShu * persenAnggotaEfektif;
    return Scaffold(
      appBar: AppBar(title: Text('Laporan RAT ${laporan.tahun}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text('Laporan Rapat Anggota Tahunan', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Tahun buku ${laporan.tahun}${laporan.alamatKantor != null ? ' · ${laporan.alamatKantor}' : ''}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
            const SizedBox(height: 20),

            const _RatSectionTitle('Visi & Misi'),
            _RatCard(children: [
              Text(laporan.visi, style: const TextStyle(fontStyle: FontStyle.italic, height: 1.35, color: KkcsColors.textPrimary)),
              const SizedBox(height: 10),
              Text(laporan.misi, style: const TextStyle(height: 1.35, color: KkcsColors.textSecondary)),
            ]),
            const SizedBox(height: 18),

            const _RatSectionTitle('Keanggotaan'),
            Row(children: [
              Expanded(child: _RatStatBox(label: 'Anggota aktif', value: '${laporan.totalAnggotaAktifSaatIni}', color: KkcsColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _RatStatBox(label: 'Anggota baru', value: '${laporan.anggotaBaruTahunIni}', color: KkcsColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: _RatStatBox(label: 'Nonaktif', value: '${laporan.totalAnggotaNonaktifSaatIni}', color: KkcsColors.textSecondary)),
            ]),
            const SizedBox(height: 18),

            if ((laporan.kegiatanBisnis ?? '').isNotEmpty || (laporan.kegiatanSosial ?? '').isNotEmpty) ...[
              const _RatSectionTitle('Laporan Kegiatan Usaha'),
              _RatCard(children: [
                if ((laporan.kegiatanBisnis ?? '').isNotEmpty) _RatLabeled('Kegiatan Bisnis', laporan.kegiatanBisnis!),
                if ((laporan.kegiatanSosial ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _RatLabeled('Kegiatan Sosial', laporan.kegiatanSosial!),
                ],
              ]),
              const SizedBox(height: 18),
            ],

            _RatSectionTitle('Ringkasan Keuangan Tahun ${laporan.tahun}'),
            _RatCard(children: [
              _RatRow('Total Aset', formatRupiah(laporan.totalAset), bold: true),
              _RatRow('Total Liabilitas (kewajiban)', formatRupiah(laporan.totalLiabilitas)),
              _RatRow('Total Ekuitas (kekayaan bersih)', formatRupiah(laporan.totalEkuitas)),
              const Divider(height: 22, color: KkcsColors.borderSubtle),
              _RatRow('Total Pendapatan', formatRupiah(laporan.totalPendapatan)),
              _RatRow('Total Beban', formatRupiah(laporan.totalBeban)),
              _RatRow('Sisa Hasil Usaha (SHU)', formatRupiah(laporan.labaBersih), bold: true),
              if (laporan.rabTotalPendapatan != null || laporan.rabTotalBeban != null) ...[
                const Divider(height: 22, color: KkcsColors.borderSubtle),
                Text('Rencana Anggaran Belanja (RAB) tahun ini', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: KkcsColors.primaryDeep)),
                const SizedBox(height: 6),
                if (laporan.rabTotalPendapatan != null) _RatRow('Rencana Pendapatan', formatRupiah(laporan.rabTotalPendapatan!)),
                if (laporan.rabTotalBeban != null) _RatRow('Rencana Beban', formatRupiah(laporan.rabTotalBeban!)),
              ],
            ]),
            const SizedBox(height: 18),

            if (shu != null) ...[
              _RatSectionTitle('Pembagian SHU Tahun ${laporan.tahun}'),
              _RatCard(children: [
                _RatRow('Total SHU', formatRupiah(shu.totalShu), bold: true),
                const SizedBox(height: 12),
                Text('Lapis 1 — Pembagian Total SHU', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800, color: KkcsColors.primary)),
                const SizedBox(height: 6),
                _shuAllocationBarLapis1(context, shu, persenAnggotaEfektif),
                const SizedBox(height: 8),
                _RatRow('Anggota (dipecah di Lapis 2) · ${(persenAnggotaEfektif * 100).toStringAsFixed(0)}%', formatRupiah(anggotaPool)),
                _RatRow('Pengurus · ${(shu.persenPengurus * 100).toStringAsFixed(0)}%', formatRupiah(shu.jasaPengurusPool)),
                _RatRow('Cadangan (ditahan permanen) · ${(shu.persenCadangan * 100).toStringAsFixed(0)}%', formatRupiah(shu.cadanganAmount)),
                const Divider(height: 26, color: KkcsColors.borderSubtle),
                Text('Lapis 2 — Pembagian Pool Anggota', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800, color: KkcsColors.warning)),
                const SizedBox(height: 6),
                _shuAllocationBarLapis2(context, persenModalEfektif, persenUsahaEfektif),
                const SizedBox(height: 8),
                _RatRow('Jasa Modal Anggota (JMA) · ${(persenModalEfektif * 100).toStringAsFixed(0)}%', formatRupiah(anggotaPool * persenModalEfektif)),
                _RatRow('Jasa Usaha Anggota (JUA) · ${(persenUsahaEfektif * 100).toStringAsFixed(0)}%', formatRupiah(anggotaPool * persenUsahaEfektif)),
                const Divider(height: 26, color: KkcsColors.borderSubtle),
                _RatRow('PPh atas bagian anggota', formatRupiah(shu.totalPajak)),
                _RatRow('Neto diterima ${shu.jumlahAnggota} anggota', formatRupiah(shu.totalShuNeto), bold: true),
              ]),
              const SizedBox(height: 18),
            ],

            if ((laporan.rencanaBisnisTahunDepan ?? '').isNotEmpty || (laporan.rencanaSosialTahunDepan ?? '').isNotEmpty) ...[
              const _RatSectionTitle('Rencana Kegiatan Tahun Depan'),
              _RatCard(children: [
                if ((laporan.rencanaBisnisTahunDepan ?? '').isNotEmpty) _RatLabeled('Rencana Bisnis', laporan.rencanaBisnisTahunDepan!),
                if ((laporan.rencanaSosialTahunDepan ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _RatLabeled('Rencana Sosial', laporan.rencanaSosialTahunDepan!),
                ],
              ]),
              const SizedBox(height: 18),
            ],

            if ((laporan.catatanTambahan ?? '').isNotEmpty) ...[
              const _RatSectionTitle('Catatan Tambahan'),
              _RatCard(children: [Text(laporan.catatanTambahan!)]),
            ],

            const SizedBox(height: 8),
            Text('Laporan ini dihasilkan otomatis oleh sistem dari data pembukuan koperasi.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black45)),
          ],
        ),
      ),
    );
  }

  Widget _shuAllocationBarLapis1(BuildContext context, LaporanRatShu shu, double persenAnggotaEfektif) {
    Widget seg(double flex, Color color) => flex <= 0 ? const SizedBox.shrink() : Expanded(flex: (flex * 100).round().clamp(1, 1000), child: Container(height: 10, color: color));
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Row(children: [
        seg(persenAnggotaEfektif, KkcsColors.primary),
        seg(shu.persenPengurus, KkcsColors.primaryDark),
        seg(shu.persenCadangan, KkcsColors.primaryDeep),
      ]),
    );
  }

  Widget _shuAllocationBarLapis2(BuildContext context, double persenModalEfektif, double persenUsahaEfektif) {
    Widget seg(double flex, Color color) => flex <= 0 ? const SizedBox.shrink() : Expanded(flex: (flex * 100).round().clamp(1, 1000), child: Container(height: 10, color: color));
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Row(children: [
        seg(persenModalEfektif, KkcsColors.primary),
        seg(persenUsahaEfektif, const Color(0xFF38BDF8)),
      ]),
    );
  }
}

class _RatSectionTitle extends StatelessWidget {
  const _RatSectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(color: KkcsColors.primary, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: KkcsColors.primaryDeep)),
          ],
        ),
      );
}

class _RatCard extends StatelessWidget {
  const _RatCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: KkcsColors.borderSubtle, width: 1.2),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      );
}

class _RatStatBox extends StatelessWidget {
  const _RatStatBox({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KkcsColors.borderSubtle, width: 1.2),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color ?? KkcsColors.primaryDeep)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: KkcsColors.textSecondary)),
        ]),
      );
}

class _RatLabeled extends StatelessWidget {
  const _RatLabeled(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: KkcsColors.primaryDeep)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 13, color: KkcsColors.textPrimary, height: 1.35)),
      ]);
}

class _RatRow extends StatelessWidget {
  const _RatRow(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                fontSize: 13,
                color: bold ? KkcsColors.textPrimary : KkcsColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
              color: bold ? KkcsColors.primaryDeep : KkcsColors.textPrimary,
            ),
          ),
        ]),
      );
}

class DigitalSavingsLoanPage extends StatelessWidget {
  const DigitalSavingsLoanPage({required this.session, super.key});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Simpanan & Pinjaman Digital'),
          bottom: const TabBar(
            indicatorColor: KkcsColors.primary,
            indicatorWeight: 3,
            labelColor: KkcsColors.primary,
            unselectedLabelColor: KkcsColors.textSecondary,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
            tabs: [
              Tab(icon: Icon(Icons.savings_outlined), text: 'Simpanan'),
              Tab(icon: Icon(Icons.request_quote_outlined), text: 'Pinjaman'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(children: [
            SavingsTab(session: session),
            LoanTab(session: session),
          ]),
        ),
      ),
    );
  }
}

class LoanTab extends StatefulWidget {
  const LoanTab({required this.session, super.key});

  final AuthSession session;

  @override
  State<LoanTab> createState() => _LoanTabState();
}

class _LoanTabState extends State<LoanTab> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '10000000');
  final _purposeController = TextEditingController();
  int _tenor = 12;
  bool _submittingLoan = false;
  bool _loadingLoans = true;
  String? _loansError;
  LoanOverview? _overview;
  int? _paymentBusyLoanId;

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;

  LoanInstallmentBreakdown get _breakdown => LoanInstallmentBreakdown.compute(_amount, _tenor);

  Future<void> _loadLoans() async {
    setState(() {
      _loadingLoans = true;
      _loansError = null;
    });
    try {
      final overview = await AuthService().fetchMyLoans();
      if (!mounted) return;
      setState(() => _overview = overview);
    } catch (error) {
      if (mounted) setState(() => _loansError = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingLoans = false);
    }
  }

  Future<void> _requestPayment(Loan loan, String jenis) async {
    final isPayoff = jenis == 'Pelunasan';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isPayoff ? 'Ajukan pelunasan dipercepat' : 'Ajukan pembayaran angsuran'),
        content: Text(isPayoff
            ? 'Anda akan mengajukan pelunasan pinjaman ${loan.nomorPinjaman} sebesar ${formatRupiah(loan.nilaiPelunasanDipercepat)} (sisa pokok). '
                'Jasa ${formatRupiah(loan.jasaDibebaskan)} dibebaskan. Pengajuan diverifikasi pengurus terlebih dahulu.'
            : 'Anda akan mengajukan pembayaran 1 angsuran ${loan.nomorPinjaman} sebesar ${formatRupiah(loan.angsuranPerBulan)}. '
                'Pengajuan diverifikasi pengurus terlebih dahulu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Ajukan')),
        ],
      ),
    );
    if (confirmed != true) return;

    PlatformFile? bukti;
    if (isPayoff) {
      if (!mounted) return;
      bukti = await pickBuktiTransfer(context);
      if (bukti == null) return;
    }

    setState(() => _paymentBusyLoanId = loan.id);
    try {
      await AuthService().requestLoanPayment(loanId: loan.id, jenis: jenis, bukti: bukti);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan terkirim. Menunggu persetujuan pengurus.')),
      );
      await _loadLoans();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _paymentBusyLoanId = null);
    }
  }

  Future<void> _submitLoan() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submittingLoan = true);
    try {
      await AuthService().submitLoan(
        nominal: _amount,
        tenorBulan: _tenor,
        tujuan: _purposeController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft pengajuan pinjaman tersimpan. Cetak draft dan lampirkan saat meminta surat rekomendasi ke SDM.')),
      );
      _purposeController.clear();
      await _loadLoans();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingLoan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview;
    final activeLoans = overview?.pinjaman.where((loan) => !loan.lunas).toList() ?? const <Loan>[];
    final settledLoans = overview?.pinjaman.where((loan) => loan.lunas).toList() ?? const <Loan>[];
    final pendingApplications = overview?.pengajuan.where((item) => item.status == 'Draft' || item.status == 'Diajukan').toList() ?? const <LoanApplication>[];

    return RefreshIndicator(
          onRefresh: _loadLoans,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, ${widget.session.user.namaLengkap.split(' ').first}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: KkcsColors.primaryDeep,
                            letterSpacing: -0.3,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ajukan pinjaman, bayar angsuran, dan pelunasan dipercepat secara paperless.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: KkcsColors.textSecondary,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              if (_loadingLoans) const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
              if (_loansError != null) Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_loansError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
              for (final loan in activeLoans) ...[
                _ActiveLoanCard(
                  loan: loan,
                  busy: _paymentBusyLoanId == loan.id,
                  onRequestPayment: (jenis) => _requestPayment(loan, jenis),
                ),
                const SizedBox(height: 16),
              ],
              for (final application in pendingApplications) ...[
                _PendingApplicationCard(application: application, onChanged: _loadLoans),
                const SizedBox(height: 16),
              ],
              _AccountSectionCard(
                icon: Icons.request_quote_outlined,
                title: 'Pengajuan Pinjaman / E-Loan',
                subtitle: 'Lengkapi formulir pengajuan pinjaman baru.',
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Nominal pinjaman', prefixText: 'Rp '),
                          onChanged: (_) => setState(() {}),
                          validator: (value) => _amount > 0 ? null : 'Nominal pinjaman wajib diisi',
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _tenor,
                          decoration: const InputDecoration(labelText: 'Tenor pinjaman'),
                          items: kLoanAnnualRates.entries
                              .map((entry) => DropdownMenuItem(
                                    value: entry.key,
                                    child: Text('${entry.key ~/ 12} tahun (${entry.key} bln) — jasa ${(entry.value * 100).toStringAsFixed(2)}%/th'),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(() => _tenor = value ?? 12),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _purposeController,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Tujuan pinjaman'),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Tujuan pinjaman wajib diisi' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _AccountSectionCard(
                icon: Icons.calculate_outlined,
                title: 'Simulasi Cicilan',
                subtitle: 'Skema KKCS: jasa flat ${(kLoanAnnualRates[_tenor]! * 100).toStringAsFixed(2)}% per tahun untuk tenor ini.',
                children: [
                  _InfoRow(label: 'Pokok pinjaman', value: formatRupiah(_amount)),
                  _InfoRow(label: 'Tenor pinjaman', value: '$_tenor bulan'),
                  const Divider(height: 18, color: KkcsColors.borderSubtle),
                  _InfoRow(label: 'Pokok / bulan', value: formatRupiah(_breakdown.principalPerMonth)),
                  _InfoRow(label: 'Jasa / bulan', value: formatRupiah(_breakdown.interestPerMonth)),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: KkcsColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Estimasi Cicilan / bln',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.primaryDeep),
                        ),
                        Text(
                          formatRupiah(_breakdown.installmentPerMonth),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: KkcsColors.primaryDeep),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 18, color: KkcsColors.borderSubtle),
                  _InfoRow(label: 'Total jasa ($_tenor bln)', value: formatRupiah(_breakdown.totalInterest)),
                  _InfoRow(label: 'Total pembayaran normal', value: formatRupiah(_breakdown.totalPayment)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: KkcsColors.borderSubtle),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: KkcsColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Jika dilunasi sebelum tenor berakhir, Anda cukup membayar sisa pokok — jasa bulan berikutnya tidak dibebankan.',
                            style: TextStyle(fontSize: 11.5, color: KkcsColors.textSecondary, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _submittingLoan ? null : _submitLoan,
                    style: FilledButton.styleFrom(
                      backgroundColor: KkcsColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _submittingLoan
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_submittingLoan ? 'Menyimpan...' : 'Simpan sebagai Draft', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (settledLoans.isNotEmpty) ...[
                const SizedBox(height: 16),
                _AccountSectionCard(
                  icon: Icons.verified_outlined,
                  title: 'Riwayat Pinjaman Lunas',
                  subtitle: 'Pinjaman yang sudah berhasil diselesaikan.',
                  children: [
                    for (final loan in settledLoans)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: KkcsColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loan.nomorPinjaman, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text('Pokok ${formatRupiah(loan.pokok)} · ${loan.tenorBulan} bulan', style: const TextStyle(fontSize: 12, color: KkcsColors.textSecondary)),
                                ],
                              ),
                            ),
                            const _StatusBadge(status: 'Dibayar'),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
  }
}

class _PendingApplicationCard extends StatefulWidget {
  const _PendingApplicationCard({required this.application, required this.onChanged});

  final LoanApplication application;
  final Future<void> Function() onChanged;

  @override
  State<_PendingApplicationCard> createState() => _PendingApplicationCardState();
}

class _PendingApplicationCardState extends State<_PendingApplicationCard> {
  bool _busy = false;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message.replaceFirst('Exception: ', ''))));
  }

  Future<void> _cetakDraft() async {
    setState(() => _busy = true);
    try {
      await AuthService().downloadAndOpenLoanDraft(
        pengajuanId: widget.application.id,
        nomorPengajuan: widget.application.nomorPengajuan,
      );
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadRekomendasi() async {
    final file = await pickBuktiTransfer(context);
    if (file == null) return;
    setState(() => _busy = true);
    try {
      await AuthService().uploadLoanRecommendation(pengajuanId: widget.application.id, file: file);
      _toast('Surat rekomendasi terunggah. Pengajuan pinjaman terkirim ke pengurus.');
      await widget.onChanged();
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.application;
    final isDraft = application.status == 'Draft';
    return Container(
      decoration: BoxDecoration(
        color: KkcsColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KkcsColors.warning.withValues(alpha: 0.35), width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: KkcsColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isDraft ? Icons.description_outlined : Icons.hourglass_top_outlined,
                  size: 18,
                  color: KkcsColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isDraft ? 'Draft Pengajuan Pinjaman' : 'Pengajuan Pinjaman Tertunda',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF92400E)),
                ),
              ),
              _StatusBadge(status: application.status),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Nomor pengajuan', value: application.nomorPengajuan),
          _InfoRow(label: 'Nominal diajukan', value: formatRupiah(application.nominal)),
          _InfoRow(label: 'Tenor pinjaman', value: '${application.tenorBulan} bulan'),
          _InfoRow(label: 'Estimasi cicilan / bulan', value: formatRupiah(application.estimasiCicilanBulanan)),
          if (isDraft) ...[
            const SizedBox(height: 12),
            const Text(
              'Cetak draft ini, lampirkan saat meminta surat rekomendasi ke SDM, lalu unggah surat '
              'rekomendasinya di sini supaya pengajuan diteruskan ke pengurus.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _cetakDraft,
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Cetak Draft'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _uploadRekomendasi,
                    icon: const Icon(Icons.upload_file_outlined, size: 16),
                    label: const Text('Unggah Rekomendasi'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveLoanCard extends StatelessWidget {
  const _ActiveLoanCard({required this.loan, required this.busy, required this.onRequestPayment});

  final Loan loan;
  final bool busy;
  final void Function(String jenis) onRequestPayment;

  @override
  Widget build(BuildContext context) {
    final progress = loan.tenorBulan == 0 ? 0.0 : loan.angsuranTerbayar / loan.tenorBulan;
    final pending = loan.pembayaranTertunda;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: KkcsColors.borderSubtle, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: KkcsColors.heroGradient,
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.request_quote_outlined, color: Color(0xFFA5F3FC), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pinjaman Aktif', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(loan.nomorPinjaman, style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: const Text('Aktif', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(KkcsColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Angsuran ${loan.angsuranTerbayar}/${loan.tenorBulan} bulan',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: KkcsColors.primaryDeep),
                    ),
                    Text(
                      'Sisa ${loan.sisaAngsuran} bulan',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: KkcsColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Pokok pinjaman', value: formatRupiah(loan.pokok)),
                _InfoRow(label: 'Cicilan / bulan', value: formatRupiah(loan.angsuranPerBulan)),
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 8),
                  child: Text(
                    'Rincian: Pokok ${formatRupiah(loan.pokokPerBulan)} + jasa ${formatRupiah(loan.jasaPerBulan)}',
                    style: const TextStyle(fontSize: 11.5, color: KkcsColors.textMuted),
                  ),
                ),
                _InfoRow(label: 'Sisa pokok pinjaman', value: formatRupiah(loan.sisaPokok)),
                const SizedBox(height: 14),
                if (pending != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: KkcsColors.warningBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KkcsColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top_outlined, size: 20, color: KkcsColors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pending.jenis == 'Pelunasan'
                                ? 'Pengajuan pelunasan dipercepat ${formatRupiah(pending.jumlahDiajukan)} sedang ditinjau pengurus.'
                                : 'Pengajuan pembayaran angsuran ${formatRupiah(pending.jumlahDiajukan)} sedang ditinjau pengurus.',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: busy ? null : () => onRequestPayment('Angsuran'),
                    style: FilledButton.styleFrom(
                      backgroundColor: KkcsColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: Text('Ajukan Pembayaran Angsuran (${formatRupiah(loan.angsuranPerBulan)})', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA), // Soft mint / teal 50
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF99F6E4), width: 1.2), // teal 200
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: KkcsColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.bolt_outlined, size: 18, color: KkcsColors.primary),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Pelunasan Dipercepat',
                              style: TextStyle(fontWeight: FontWeight.w800, color: KkcsColors.primaryDeep, fontSize: 14),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: KkcsColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Bebas Jasa', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: KkcsColors.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text('Nominal pelunasan (sisa pokok)', style: TextStyle(fontSize: 12, color: KkcsColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          formatRupiah(loan.nilaiPelunasanDipercepat),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: KkcsColors.primaryDeep, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loan.jasaDibebaskan > 0
                              ? 'Hanya sisa pokok — sisa jasa ${formatRupiah(loan.jasaDibebaskan)} dibebaskan sepenuhnya.'
                              : 'Anda hanya membayar sisa pokok, tanpa beban bunga di bulan berikutnya.',
                          style: const TextStyle(fontSize: 12, color: KkcsColors.textSecondary, height: 1.3),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : () => onRequestPayment('Pelunasan'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: KkcsColors.primaryDeep,
                              side: const BorderSide(color: KkcsColors.primary, width: 1.4),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.bolt_outlined, size: 18, color: KkcsColors.primary),
                            label: const Text('Ajukan Pelunasan Dipercepat', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Pengajuan diverifikasi pengurus koperasi sebelum pinjaman dinyatakan lunas.',
                          style: TextStyle(fontSize: 11, color: KkcsColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: const Text('Lihat jadwal angsuran', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    children: [_LoanScheduleTable(installments: loan.angsuran)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanScheduleTable extends StatelessWidget {
  const _LoanScheduleTable({required this.installments});

  final List<LoanInstallment> installments;

  String _month(DateTime date) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${names[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        headingRowHeight: 36,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 44,
        columns: const [
          DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.w800))),
          DataColumn(label: Text('Jatuh tempo', style: TextStyle(fontWeight: FontWeight.w800))),
          DataColumn(label: Text('Pokok', style: TextStyle(fontWeight: FontWeight.w800))),
          DataColumn(label: Text('Jasa', style: TextStyle(fontWeight: FontWeight.w800))),
          DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.w800))),
          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w800))),
        ],
        rows: [
          for (final item in installments)
            DataRow(cells: [
              DataCell(Text(item.jenis == 'Pelunasan' ? '⚡' : '${item.angsuranKe}', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(_month(item.jatuhTempo))),
              DataCell(Text(formatRupiah(item.pokok))),
              DataCell(Text(item.jasa == 0 ? '—' : formatRupiah(item.jasa))),
              DataCell(Text(formatRupiah(item.total), style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(_StatusBadge(status: item.status)),
            ]),
        ],
      ),
    );
  }
}

class BusinessUnitPage extends StatefulWidget {
  const BusinessUnitPage({required this.session, super.key});

  final AuthSession session;

  @override
  State<BusinessUnitPage> createState() => _BusinessUnitPageState();
}

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.kode,
    required this.nama,
    this.deskripsi,
    required this.jenis,
    required this.harga,
    required this.stok,
    required this.satuan,
    this.fotoUrl,
    required this.sumber,
    this.diajukanOleh,
    required this.status,
    required this.aktif,
    this.catatanReview,
  });

  final int id;
  final String kode;
  final String nama;
  final String? deskripsi;
  final String jenis; // Jual | Sewa
  final double harga;
  final double stok;
  final String satuan;
  final String? fotoUrl;
  final String sumber; // Koperasi | TitipanAnggota
  final String? diajukanOleh;
  final String status; // MenungguPersetujuan | Disetujui | Ditolak
  final bool aktif;
  final String? catatanReview;

  bool get sewa => jenis == 'Sewa';

  factory CatalogProduct.fromJson(Map<String, dynamic> json) => CatalogProduct(
        id: json['id'] as int,
        kode: json['kode'] as String,
        nama: json['nama'] as String,
        deskripsi: json['deskripsi'] as String?,
        jenis: json['jenis'] as String,
        harga: (json['harga'] as num).toDouble(),
        stok: (json['stok'] as num).toDouble(),
        satuan: json['satuan'] as String,
        fotoUrl: json['fotoUrl'] as String?,
        sumber: json['sumber'] as String,
        diajukanOleh: json['diajukanOleh'] as String?,
        status: json['status'] as String,
        aktif: json['aktif'] as bool,
        catatanReview: json['catatanReview'] as String?,
      );
}

class ProductPurchase {
  const ProductPurchase({
    required this.id,
    required this.nomorTransaksi,
    required this.produkNama,
    required this.jenis,
    required this.jumlah,
    required this.total,
    required this.metodePembayaran,
    required this.status,
    this.catatanReview,
    this.tagihanKreditStatus,
  });

  final int id;
  final String nomorTransaksi;
  final String produkNama;
  final String jenis;
  final double jumlah;
  final double total;
  final String metodePembayaran;
  final String status;
  final String? catatanReview;
  final String? tagihanKreditStatus;

  factory ProductPurchase.fromJson(Map<String, dynamic> json) => ProductPurchase(
        id: json['id'] as int,
        nomorTransaksi: json['nomorTransaksi'] as String,
        produkNama: json['produkNama'] as String,
        jenis: json['jenis'] as String,
        jumlah: (json['jumlah'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
        metodePembayaran: json['metodePembayaran'] as String,
        status: json['status'] as String,
        catatanReview: json['catatanReview'] as String?,
        tagihanKreditStatus: (json['tagihanKredit'] as Map<String, dynamic>?)?['status'] as String?,
      );
}

class _BusinessUnitPageState extends State<BusinessUnitPage> {
  bool _loading = true;
  String? _error;
  bool _busy = false;
  List<CatalogProduct> _catalog = const [];
  List<CatalogProduct> _myListings = const [];
  List<ProductPurchase> _myPurchases = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AuthService().fetchCatalog(),
        AuthService().fetchMyListings(),
        AuthService().fetchMyPurchases(),
      ]);
      if (!mounted) return;
      setState(() {
        _catalog = results[0] as List<CatalogProduct>;
        _myListings = results[1] as List<CatalogProduct>;
        _myPurchases = results[2] as List<ProductPurchase>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message.replaceFirst('Exception: ', ''))));
  }

  Future<void> _buy(CatalogProduct product) async {
    final result = await showModalBottomSheet<({double jumlah, String metode, String? catatan})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BuySheet(product: product),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await AuthService().buyProduct(
        produkId: product.id,
        jumlah: result.jumlah,
        metodePembayaran: result.metode,
        catatan: result.catatan,
      );
      if (!mounted) return;
      _toast('Pengajuan ${product.sewa ? 'sewa' : 'pembelian'} terkirim. Menunggu persetujuan pengurus.');
      await _load();
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sell() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SellProductPage()),
    );
    if (ok == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog Produk Koperasi'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Muat ulang')],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Katalog Produk Koperasi',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: KkcsColors.primaryDeep,
                            letterSpacing: -0.3,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Beli atau sewa produk koperasi, atau jual produk Anda ke koperasi.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: KkcsColors.textSecondary,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              if (_loading) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator(minHeight: 2)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              if (!_loading && _catalog.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KkcsColors.borderSubtle, width: 1.2),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: KkcsColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.inventory_2_outlined, size: 32, color: KkcsColors.primary),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum ada produk di katalog.',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: KkcsColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Produk yang tersedia untuk dijual atau disewa akan muncul di sini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: KkcsColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ..._catalog.map((product) => _CatalogProductCard(
                    product: product,
                    onBuy: _busy ? null : () => _buy(product),
                  )),
              const SizedBox(height: 10),
              _AccountSectionCard(
                icon: Icons.sell_outlined,
                title: 'Jual produk ke koperasi',
                subtitle: 'Ajukan barang milik Anda untuk dijual / disewakan lewat koperasi. Disetujui pengurus dulu.',
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _sell,
                    style: FilledButton.styleFrom(
                      backgroundColor: KkcsColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_business_outlined, size: 18),
                    label: const Text('Ajukan produk baru', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  if (_myListings.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('Produk yang Anda Ajukan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.textPrimary)),
                    const SizedBox(height: 6),
                    ..._myListings.map((item) => Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: KkcsColors.borderSubtle),
                          ),
                          child: Row(children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: KkcsColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.storefront_outlined, size: 18, color: KkcsColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.nama, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.textPrimary)),
                                  Text(
                                    '${formatRupiah(item.harga)} / ${item.satuan} · ${item.sewa ? 'Disewakan' : 'Dijual'}',
                                    style: const TextStyle(fontSize: 12, color: KkcsColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            _StatusBadge(status: item.status),
                          ]),
                        )),
                  ],
                ],
              ),
              if (_myPurchases.isNotEmpty) ...[
                const SizedBox(height: 14),
                _AccountSectionCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Transaksi saya',
                  subtitle: 'Riwayat pembelian & penyewaan produk.',
                  children: _myPurchases
                      .map((p) => Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: KkcsColors.borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: p.jenis == 'Sewa' ? const Color(0xFFE0F2FE) : KkcsColors.primaryLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        p.jenis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: p.jenis == 'Sewa' ? const Color(0xFF0369A1) : KkcsColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        p.produkNama,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.textPrimary),
                                      ),
                                    ),
                                    _StatusBadge(status: p.status),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      p.metodePembayaran == 'Kredit'
                                          ? 'Kredit · tagihan: ${p.tagihanKreditStatus ?? 'menunggu'}'
                                          : 'Tunai',
                                      style: const TextStyle(fontSize: 12, color: KkcsColors.textSecondary),
                                    ),
                                    Text(
                                      formatRupiah(p.total),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: KkcsColors.primaryDeep),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogProductCard extends StatelessWidget {
  const _CatalogProductCard({required this.product, required this.onBuy});

  final CatalogProduct product;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final habis = !product.sewa && product.stok <= 0;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: KkcsColors.borderSubtle, width: 1.2),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: product.fotoUrl == null
                    ? Container(
                        color: KkcsColors.primaryLight,
                        child: const Icon(Icons.inventory_2_outlined, color: KkcsColors.primary, size: 28),
                      )
                    : Image.network(
                        '${AuthService.baseUrl}${product.fotoUrl}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: KkcsColors.primaryLight,
                          child: const Icon(Icons.broken_image_outlined, color: KkcsColors.textDisabled, size: 28),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.nama,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: KkcsColors.textPrimary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: product.sewa ? const Color(0xFFE0F2FE) : KkcsColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.sewa ? 'Sewa' : 'Jual',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: product.sewa ? const Color(0xFF0369A1) : KkcsColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatRupiah(product.harga)} / ${product.satuan}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: KkcsColors.primaryDeep),
                  ),
                  if (product.deskripsi != null && product.deskripsi!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      product.deskripsi!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: KkcsColors.textSecondary, height: 1.25),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.sewa
                              ? (product.sumber == 'TitipanAnggota' ? 'Titipan ${product.diajukanOleh ?? 'anggota'}' : 'Milik koperasi')
                              : (habis ? 'Stok habis' : 'Stok: ${product.stok.toStringAsFixed(product.stok % 1 == 0 ? 0 : 2)} ${product.satuan}'),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: habis ? FontWeight.w700 : FontWeight.w500,
                            color: habis ? KkcsColors.danger : KkcsColors.textSecondary,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: habis ? null : onBuy,
                        style: FilledButton.styleFrom(
                          backgroundColor: KkcsColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          product.sewa ? 'Sewa' : 'Beli',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuySheet extends StatefulWidget {
  const _BuySheet({required this.product});
  final CatalogProduct product;

  @override
  State<_BuySheet> createState() => _BuySheetState();
}

class _BuySheetState extends State<_BuySheet> {
  final _jumlahController = TextEditingController(text: '1');
  final _catatanController = TextEditingController();
  String _metode = 'Tunai';

  @override
  void dispose() {
    _jumlahController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  double get _jumlah => double.tryParse(_jumlahController.text.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KkcsColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(p.sewa ? Icons.handshake_outlined : Icons.shopping_bag_outlined, color: KkcsColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.sewa ? 'Sewa' : 'Beli'} ${p.nama}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: KkcsColors.textPrimary),
                    ),
                    Text(
                      '${formatRupiah(p.harga)} / ${p.satuan}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _jumlahController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: p.sewa ? 'Jumlah / durasi sewa' : 'Jumlah pembelian',
              suffixText: p.satuan,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _metode = 'Tunai'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _metode == 'Tunai' ? KkcsColors.primaryLight : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _metode == 'Tunai' ? KkcsColors.primary : KkcsColors.borderSubtle,
                        width: _metode == 'Tunai' ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payments_outlined, size: 18, color: _metode == 'Tunai' ? KkcsColors.primary : KkcsColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Tunai',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: _metode == 'Tunai' ? KkcsColors.primaryDeep : KkcsColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Dibayar fisik ke pengurus',
                          style: TextStyle(fontSize: 10.5, color: KkcsColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _metode = 'Kredit'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _metode == 'Kredit' ? KkcsColors.primaryLight : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _metode == 'Kredit' ? KkcsColors.primary : KkcsColors.borderSubtle,
                        width: _metode == 'Kredit' ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.credit_card_outlined, size: 18, color: _metode == 'Kredit' ? KkcsColors.primary : KkcsColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Kredit',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: _metode == 'Kredit' ? KkcsColors.primaryDeep : KkcsColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Tagihan potong gaji',
                          style: TextStyle(fontSize: 10.5, color: KkcsColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _catatanController,
            decoration: InputDecoration(
              labelText: 'Catatan (opsional)',
              hintText: 'Contoh: Titip di meja piket / sewa 2 hari',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF99F6E4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Pembayaran', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.primaryDeep)),
                Text(
                  formatRupiah(p.harga * _jumlah),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: KkcsColors.primaryDeep),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _jumlah <= 0
                ? null
                : () => Navigator.pop(context, (
                    jumlah: _jumlah,
                    metode: _metode,
                    catatan: _catatanController.text.trim().isEmpty ? null : _catatanController.text.trim(),
                  )),
            style: FilledButton.styleFrom(
              backgroundColor: KkcsColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ajukan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class SellProductPage extends StatefulWidget {
  const SellProductPage({super.key});

  @override
  State<SellProductPage> createState() => _SellProductPageState();
}

class _SellProductPageState extends State<SellProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _hargaController = TextEditingController();
  final _stokController = TextEditingController(text: '1');
  final _satuanController = TextEditingController(text: 'unit');
  String _jenis = 'Jual';
  XFile? _foto;
  bool _saving = false;

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    _hargaController.dispose();
    _stokController.dispose();
    _satuanController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1400);
    if (photo != null) setState(() => _foto = photo);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final produk = await AuthService().submitProductListing(
        nama: _namaController.text,
        deskripsi: _deskripsiController.text,
        jenis: _jenis,
        harga: double.parse(_hargaController.text.replaceAll('.', '').replaceAll(',', '')),
        stok: double.tryParse(_stokController.text.replaceAll(',', '.')) ?? 1,
        satuan: _satuanController.text,
      );
      if (_foto != null) {
        await AuthService().uploadProductListingPhoto(produk.id, _foto!);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan produk terkirim. Menunggu persetujuan pengurus.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jual produk ke koperasi')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: KkcsColors.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Barang yang disetujui akan menjadi milik koperasi dan tampil di katalog. Pelunasan ke Anda diatur pengurus.',
                        style: TextStyle(fontSize: 12, color: KkcsColors.primaryDeep, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: _foto == null ? KkcsColors.primaryLight : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _foto == null ? KkcsColors.primary.withValues(alpha: 0.4) : KkcsColors.success,
                      width: 1.4,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _foto == null ? Colors.white : KkcsColors.successBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _foto == null ? Icons.add_a_photo_outlined : Icons.check_circle_outline,
                          color: _foto == null ? KkcsColors.primary : KkcsColors.success,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _foto == null ? 'Tambahkan foto produk (opsional)' : 'Foto dipilih: ${_foto!.name}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _foto == null ? KkcsColors.primaryDeep : KkcsColors.success,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _namaController,
                decoration: InputDecoration(
                  labelText: 'Nama produk',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deskripsiController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Deskripsi (opsional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _jenis,
                decoration: InputDecoration(
                  labelText: 'Kriteria penawaran',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'Jual', child: Text('Penjualan — Dijual ke Koperasi')),
                  DropdownMenuItem(value: 'Sewa', child: Text('Penyewaan — Disewakan lewat Koperasi')),
                ],
                onChanged: (v) => setState(() {
                  _jenis = v ?? 'Jual';
                  if (_jenis == 'Sewa') {
                    _satuanController.text = 'Hari';
                    _stokController.text = '0';
                  } else if (_satuanController.text == 'Hari' || _satuanController.text == 'Bulan') {
                    _satuanController.text = 'unit';
                  }
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hargaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _jenis == 'Sewa' ? 'Tarif sewa' : 'Harga jual',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll('.', '').replaceAll(',', ''));
                  return n == null || n <= 0 ? 'Harga tidak valid' : null;
                },
              ),
              const SizedBox(height: 12),
              if (_jenis == 'Sewa')
                DropdownButtonFormField<String>(
                  value: _satuanController.text == 'Bulan' ? 'Bulan' : 'Hari',
                  decoration: InputDecoration(
                    labelText: 'Periode sewa',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Hari', child: Text('Harian')),
                    DropdownMenuItem(value: 'Bulan', child: Text('Bulanan')),
                  ],
                  onChanged: (v) => setState(() => _satuanController.text = v ?? 'Hari'),
                )
              else
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stokController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Stok / jumlah',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _satuanController,
                      decoration: InputDecoration(
                        labelText: 'Satuan (unit/kg)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                ]),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: KkcsColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_outlined, size: 18),
                label: Text(_saving ? 'Mengirim...' : 'Kirim Pengajuan Produk', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pinjaman ─────────────────────────────────────────────────────────────────
// Tabel Pinjaman KKCS (per 1 Juli 2023): bunga flat tahunan menurut tenor.
const Map<int, double> kLoanAnnualRates = {
  12: 0.0700,
  24: 0.0725,
  36: 0.0750,
  48: 0.0800,
  60: 0.0850,
};

String formatRupiah(num value) {
  final rounded = value.round().toString();
  final withDots = rounded.replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+$)'), (_) => '.');
  return 'Rp $withDots';
}

/// Minta anggota memilih 1 file bukti transfer (JPG/PNG/PDF, maks 10MB) dan kembalikan sebagai
/// [PlatformFile] siap-unggah (bytes sudah dimuat). Null kalau anggota membatalkan pemilihan.
/// Menampilkan snackbar error kalau file terlalu besar atau gagal dibaca.
Future<PlatformFile?> pickBuktiTransfer(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  if (file.bytes == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membaca file yang dipilih. Coba lagi.')),
      );
    }
    return null;
  }
  if (file.size > 10 * 1024 * 1024) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ukuran file maksimal 10MB.')),
      );
    }
    return null;
  }
  return file;
}

/// Rincian satu angsuran: pokok (inti) + jasa (bunga).
class LoanInstallmentBreakdown {
  const LoanInstallmentBreakdown({
    required this.principalPerMonth,
    required this.interestPerMonth,
    required this.installmentPerMonth,
    required this.totalInterest,
    required this.totalPayment,
  });

  final double principalPerMonth;
  final double interestPerMonth;
  final double installmentPerMonth;
  final double totalInterest;
  final double totalPayment;

  factory LoanInstallmentBreakdown.compute(double nominal, int tenorBulan) {
    final rate = kLoanAnnualRates[tenorBulan] ?? 0;
    final principal = nominal <= 0 ? 0.0 : (nominal / tenorBulan);
    final interest = nominal <= 0 ? 0.0 : (nominal * rate / 12);
    return LoanInstallmentBreakdown(
      principalPerMonth: principal,
      interestPerMonth: interest,
      installmentPerMonth: principal + interest,
      totalInterest: interest * tenorBulan,
      totalPayment: nominal + interest * tenorBulan,
    );
  }
}

class LoanApplication {
  const LoanApplication({
    required this.id,
    required this.nomorPengajuan,
    required this.nominal,
    required this.tenorBulan,
    required this.bungaTahunan,
    required this.estimasiCicilanBulanan,
    required this.estimasiTotalJasa,
    required this.tujuan,
    required this.status,
    this.catatanReview,
    this.suratRekomendasiUrl,
  });

  final int id;
  final String nomorPengajuan;
  final double nominal;
  final int tenorBulan;
  final double bungaTahunan;
  final double estimasiCicilanBulanan;
  final double estimasiTotalJasa;
  final String tujuan;
  final String status;
  final String? catatanReview;
  final String? suratRekomendasiUrl;

  factory LoanApplication.fromJson(Map<String, dynamic> json) => LoanApplication(
        id: json['id'] as int,
        nomorPengajuan: json['nomorPengajuan'] as String,
        nominal: (json['nominal'] as num).toDouble(),
        tenorBulan: json['tenorBulan'] as int,
        bungaTahunan: (json['bungaTahunan'] as num).toDouble(),
        estimasiCicilanBulanan: (json['estimasiCicilanBulanan'] as num).toDouble(),
        estimasiTotalJasa: (json['estimasiTotalJasa'] as num).toDouble(),
        tujuan: json['tujuan'] as String,
        status: json['status'] as String,
        catatanReview: json['catatanReview'] as String?,
        suratRekomendasiUrl: json['suratRekomendasiUrl'] as String?,
      );
}

class LoanInstallment {
  const LoanInstallment({
    required this.angsuranKe,
    required this.jatuhTempo,
    required this.pokok,
    required this.jasa,
    required this.total,
    required this.jenis,
    required this.status,
  });

  final int angsuranKe;
  final DateTime jatuhTempo;
  final double pokok;
  final double jasa;
  final double total;
  final String jenis;
  final String status;

  factory LoanInstallment.fromJson(Map<String, dynamic> json) => LoanInstallment(
        angsuranKe: json['angsuranKe'] as int,
        jatuhTempo: DateTime.parse(json['jatuhTempo'] as String),
        pokok: (json['pokok'] as num).toDouble(),
        jasa: (json['jasa'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
        jenis: json['jenis'] as String,
        status: json['status'] as String,
      );
}

class PendingLoanPayment {
  const PendingLoanPayment({required this.jenis, required this.jumlahDiajukan});

  final String jenis;
  final double jumlahDiajukan;

  factory PendingLoanPayment.fromJson(Map<String, dynamic> json) => PendingLoanPayment(
        jenis: json['jenis'] as String,
        jumlahDiajukan: (json['jumlahDiajukan'] as num).toDouble(),
      );
}

class Loan {
  const Loan({
    required this.id,
    required this.nomorPinjaman,
    required this.pokok,
    required this.tenorBulan,
    required this.bungaTahunan,
    required this.pokokPerBulan,
    required this.jasaPerBulan,
    required this.angsuranPerBulan,
    required this.sisaPokok,
    required this.angsuranTerbayar,
    required this.sisaAngsuran,
    required this.status,
    required this.nilaiPelunasanDipercepat,
    required this.jasaDibebaskan,
    required this.pembayaranTertunda,
    required this.angsuran,
  });

  final int id;
  final String nomorPinjaman;
  final double pokok;
  final int tenorBulan;
  final double bungaTahunan;
  final double pokokPerBulan;
  final double jasaPerBulan;
  final double angsuranPerBulan;
  final double sisaPokok;
  final int angsuranTerbayar;
  final int sisaAngsuran;
  final String status;
  final double nilaiPelunasanDipercepat;
  final double jasaDibebaskan;
  final PendingLoanPayment? pembayaranTertunda;
  final List<LoanInstallment> angsuran;

  bool get lunas => status == 'Lunas';

  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
        id: json['id'] as int,
        nomorPinjaman: json['nomorPinjaman'] as String,
        pokok: (json['pokok'] as num).toDouble(),
        tenorBulan: json['tenorBulan'] as int,
        bungaTahunan: (json['bungaTahunan'] as num).toDouble(),
        pokokPerBulan: (json['pokokPerBulan'] as num).toDouble(),
        jasaPerBulan: (json['jasaPerBulan'] as num).toDouble(),
        angsuranPerBulan: (json['angsuranPerBulan'] as num).toDouble(),
        sisaPokok: (json['sisaPokok'] as num).toDouble(),
        angsuranTerbayar: json['angsuranTerbayar'] as int,
        sisaAngsuran: json['sisaAngsuran'] as int,
        status: json['status'] as String,
        nilaiPelunasanDipercepat: (json['nilaiPelunasanDipercepat'] as num).toDouble(),
        jasaDibebaskan: (json['jasaDibebaskan'] as num).toDouble(),
        pembayaranTertunda: json['pembayaranTertunda'] == null
            ? null
            : PendingLoanPayment.fromJson(json['pembayaranTertunda'] as Map<String, dynamic>),
        angsuran: (json['angsuran'] as List<dynamic>)
            .map((item) => LoanInstallment.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class LoanOverview {
  const LoanOverview({required this.pengajuan, required this.pinjaman});

  final List<LoanApplication> pengajuan;
  final List<Loan> pinjaman;

  factory LoanOverview.fromJson(Map<String, dynamic> json) => LoanOverview(
        pengajuan: (json['pengajuan'] as List<dynamic>)
            .map((item) => LoanApplication.fromJson(item as Map<String, dynamic>))
            .toList(),
        pinjaman: (json['pinjaman'] as List<dynamic>)
            .map((item) => Loan.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

// ── Beranda ──────────────────────────────────────────────────────────────────
class Announcement {
  const Announcement({required this.ikon, required this.judul, required this.isi, required this.tautan});
  final String ikon; // vote | dokumen | produk | info
  final String judul;
  final String isi;
  final String tautan; // erat | katalog | simpanan | pinjaman | ''
  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        ikon: json['ikon'] as String,
        judul: json['judul'] as String,
        isi: json['isi'] as String,
        tautan: json['tautan'] as String,
      );
}

class HomeSummary {
  const HomeSummary({
    required this.totalSimpanan,
    required this.simpananPokok,
    required this.simpananWajib,
    required this.simpananSukarela,
    required this.simpananBerjangka,
    required this.jumlahPinjamanAktif,
    required this.sisaPokokPinjaman,
    required this.cicilanBulananBerjalan,
    required this.sisaAngsuran,
    required this.pengumuman,
    required this.produkTerbaru,
    this.estimasiShuTahun,
    this.estimasiShuNominal,
  });

  final double totalSimpanan;
  final double simpananPokok;
  final double simpananWajib;
  final double simpananSukarela;
  final double simpananBerjangka;
  final int jumlahPinjamanAktif;
  final double sisaPokokPinjaman;
  final double cicilanBulananBerjalan;
  final int sisaAngsuran;
  final List<Announcement> pengumuman;
  final List<CatalogProduct> produkTerbaru;
  final int? estimasiShuTahun;
  final double? estimasiShuNominal;

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    final estimasiShu = json['estimasiShu'] as Map<String, dynamic>?;
    return HomeSummary(
      totalSimpanan: (json['totalSimpanan'] as num).toDouble(),
      simpananPokok: (json['simpananPokok'] as num).toDouble(),
      simpananWajib: (json['simpananWajib'] as num).toDouble(),
      simpananSukarela: (json['simpananSukarela'] as num).toDouble(),
      simpananBerjangka: (json['simpananBerjangka'] as num).toDouble(),
      jumlahPinjamanAktif: json['jumlahPinjamanAktif'] as int,
      sisaPokokPinjaman: (json['sisaPokokPinjaman'] as num).toDouble(),
      cicilanBulananBerjalan: (json['cicilanBulananBerjalan'] as num).toDouble(),
      sisaAngsuran: json['sisaAngsuran'] as int,
      pengumuman: (json['pengumuman'] as List<dynamic>? ?? [])
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList(),
      produkTerbaru: (json['produkTerbaru'] as List<dynamic>? ?? [])
          .map((e) => CatalogProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      estimasiShuTahun: estimasiShu?['tahun'] as int?,
      estimasiShuNominal: (estimasiShu?['totalShu'] as num?)?.toDouble(),
    );
  }
}

// ── SHU (Sisa Hasil Usaha) ──────────────────────────────────────────────────
class ShuHistoryEntry {
  const ShuHistoryEntry({
    required this.tahun,
    required this.simpananAnggota,
    required this.transaksiAnggota,
    required this.jma,
    required this.jua,
    required this.totalShu,
    required this.pajak,
    required this.totalShuNeto,
    required this.persenJasaModal,
    required this.persenJasaUsaha,
    required this.difinalisasiPada,
  });

  final int tahun;
  final double simpananAnggota;
  final double transaksiAnggota;
  final double jma;
  final double jua;
  final double totalShu;
  final double pajak;
  final double totalShuNeto;
  final double persenJasaModal;
  final double persenJasaUsaha;
  final DateTime difinalisasiPada;

  factory ShuHistoryEntry.fromJson(Map<String, dynamic> json) => ShuHistoryEntry(
        tahun: json['tahun'] as int,
        simpananAnggota: (json['simpananAnggota'] as num).toDouble(),
        transaksiAnggota: (json['transaksiAnggota'] as num).toDouble(),
        jma: (json['jma'] as num).toDouble(),
        jua: (json['jua'] as num).toDouble(),
        totalShu: (json['totalShu'] as num).toDouble(),
        pajak: (json['pajak'] as num).toDouble(),
        totalShuNeto: (json['totalShuNeto'] as num).toDouble(),
        persenJasaModal: (json['persenJasaModal'] as num).toDouble(),
        persenJasaUsaha: (json['persenJasaUsaha'] as num).toDouble(),
        difinalisasiPada: DateTime.parse(json['difinalisasiPada'] as String),
      );
}

// ── Simpanan ─────────────────────────────────────────────────────────────────
class SavingsAccount {
  const SavingsAccount({required this.saldo, this.nomorRekening});
  final double saldo;
  final String? nomorRekening;
  factory SavingsAccount.fromJson(Map<String, dynamic> json) => SavingsAccount(
        saldo: (json['saldo'] as num).toDouble(),
        nomorRekening: json['nomorRekening'] as String?,
      );
}

class WajibBill {
  const WajibBill({required this.id, required this.periode, required this.nominal, required this.jatuhTempo, required this.status});
  final int id;
  final String periode;
  final double nominal;
  final DateTime jatuhTempo;
  final String status;
  factory WajibBill.fromJson(Map<String, dynamic> json) => WajibBill(
        id: json['id'] as int,
        periode: json['periode'] as String,
        nominal: (json['nominal'] as num).toDouble(),
        jatuhTempo: DateTime.parse(json['jatuhTempo'] as String),
        status: json['status'] as String,
      );
}

class WajibSection {
  const WajibSection({required this.saldo, required this.nominalBulanan, required this.tanggalTagih, required this.tagihan});
  final double saldo;
  final double nominalBulanan;
  final int tanggalTagih;
  final List<WajibBill> tagihan;
  factory WajibSection.fromJson(Map<String, dynamic> json) => WajibSection(
        saldo: (json['saldo'] as num).toDouble(),
        nominalBulanan: (json['nominalBulanan'] as num).toDouble(),
        tanggalTagih: json['tanggalTagih'] as int,
        tagihan: (json['tagihan'] as List<dynamic>).map((e) => WajibBill.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class SukarelaRequest {
  const SukarelaRequest({required this.id, required this.jenis, required this.nominal, required this.status, required this.diajukanPada, this.catatanReview});
  final int id;
  final String jenis;
  final double nominal;
  final String status;
  final DateTime diajukanPada;
  final String? catatanReview;
  factory SukarelaRequest.fromJson(Map<String, dynamic> json) => SukarelaRequest(
        id: json['id'] as int,
        jenis: json['jenis'] as String,
        nominal: (json['nominal'] as num).toDouble(),
        status: json['status'] as String,
        diajukanPada: DateTime.parse(json['diajukanPada'] as String),
        catatanReview: json['catatanReview'] as String?,
      );
}

class SukarelaSection {
  const SukarelaSection({required this.saldo, required this.bungaTahunan, required this.tarifPphBunga, required this.pengajuan});
  final double saldo;
  final double bungaTahunan;
  final double tarifPphBunga;
  final List<SukarelaRequest> pengajuan;
  factory SukarelaSection.fromJson(Map<String, dynamic> json) => SukarelaSection(
        saldo: (json['saldo'] as num).toDouble(),
        bungaTahunan: (json['bungaTahunan'] as num?)?.toDouble() ?? 0,
        tarifPphBunga: (json['tarifPphBunga'] as num?)?.toDouble() ?? 0,
        pengajuan: (json['pengajuan'] as List<dynamic>).map((e) => SukarelaRequest.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class BerjangkaProduct {
  const BerjangkaProduct({required this.id, required this.nama, required this.nominal, required this.tenorBulan});
  final int id;
  final String nama;
  final double nominal;
  final int tenorBulan;
  factory BerjangkaProduct.fromJson(Map<String, dynamic> json) => BerjangkaProduct(
        id: json['id'] as int,
        nama: json['nama'] as String,
        nominal: (json['nominal'] as num).toDouble(),
        tenorBulan: json['tenorBulan'] as int,
      );
}

class TermDeposit {
  const TermDeposit({required this.id, required this.nomorSertifikat, required this.produkNama, required this.nominal, required this.tenorBulan, required this.status, this.tanggalMulai, this.tanggalJatuhTempo, required this.estimasiBunga, this.bungaDibayar, required this.pencairanDiajukan});
  final int id;
  final String nomorSertifikat;
  final String produkNama;
  final double nominal;
  final int tenorBulan;
  final String status;
  final DateTime? tanggalMulai;
  final DateTime? tanggalJatuhTempo;
  final double estimasiBunga;
  final double? bungaDibayar;
  final bool pencairanDiajukan;
  factory TermDeposit.fromJson(Map<String, dynamic> json) => TermDeposit(
        id: json['id'] as int,
        nomorSertifikat: json['nomorSertifikat'] as String,
        produkNama: json['produkNama'] as String,
        nominal: (json['nominal'] as num).toDouble(),
        tenorBulan: json['tenorBulan'] as int,
        status: json['status'] as String,
        tanggalMulai: json['tanggalMulai'] == null ? null : DateTime.parse(json['tanggalMulai'] as String),
        tanggalJatuhTempo: json['tanggalJatuhTempo'] == null ? null : DateTime.parse(json['tanggalJatuhTempo'] as String),
        estimasiBunga: (json['estimasiBunga'] as num?)?.toDouble() ?? 0,
        bungaDibayar: (json['bungaDibayar'] as num?)?.toDouble(),
        pencairanDiajukan: json['pencairanDiajukan'] as bool? ?? false,
      );
}

class BerjangkaSection {
  const BerjangkaSection({required this.bungaTahunan, required this.produk, required this.milikSaya});
  final double bungaTahunan;
  final List<BerjangkaProduct> produk;
  final List<TermDeposit> milikSaya;
  factory BerjangkaSection.fromJson(Map<String, dynamic> json) => BerjangkaSection(
        bungaTahunan: (json['bungaTahunan'] as num?)?.toDouble() ?? 0,
        produk: (json['produk'] as List<dynamic>).map((e) => BerjangkaProduct.fromJson(e as Map<String, dynamic>)).toList(),
        milikSaya: (json['milikSaya'] as List<dynamic>).map((e) => TermDeposit.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class SavingsMutation {
  const SavingsMutation({required this.rekening, required this.jenis, required this.nominal, required this.saldoSetelah, this.keterangan, required this.tanggal});
  final String rekening;
  final String jenis;
  final double nominal;
  final double saldoSetelah;
  final String? keterangan;
  final DateTime tanggal;
  factory SavingsMutation.fromJson(Map<String, dynamic> json) => SavingsMutation(
        rekening: json['rekening'] as String,
        jenis: json['jenis'] as String,
        nominal: (json['nominal'] as num).toDouble(),
        saldoSetelah: (json['saldoSetelah'] as num).toDouble(),
        keterangan: json['keterangan'] as String?,
        tanggal: DateTime.parse(json['tanggal'] as String),
      );
}

class SavingsOverview {
  const SavingsOverview({required this.pokok, required this.wajib, required this.sukarela, required this.berjangka, required this.mutasi});
  final SavingsAccount pokok;
  final WajibSection wajib;
  final SukarelaSection sukarela;
  final BerjangkaSection berjangka;
  final List<SavingsMutation> mutasi;
  factory SavingsOverview.fromJson(Map<String, dynamic> json) => SavingsOverview(
        pokok: SavingsAccount.fromJson(json['pokok'] as Map<String, dynamic>),
        wajib: WajibSection.fromJson(json['wajib'] as Map<String, dynamic>),
        sukarela: SukarelaSection.fromJson(json['sukarela'] as Map<String, dynamic>),
        berjangka: BerjangkaSection.fromJson(json['berjangka'] as Map<String, dynamic>),
        mutasi: (json['mutasiTerakhir'] as List<dynamic>).map((e) => SavingsMutation.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class SukarelaRutinInfo {
  const SukarelaRutinInfo({
    required this.id,
    required this.nominal,
    required this.tanggalSetor,
    required this.status,
    this.catatanReview,
    this.terakhirDijalankanPeriode,
  });

  final int id;
  final double nominal;
  final int tanggalSetor;
  final String status;
  final String? catatanReview;
  final String? terakhirDijalankanPeriode;

  factory SukarelaRutinInfo.fromJson(Map<String, dynamic> json) => SukarelaRutinInfo(
        id: json['id'] as int,
        nominal: (json['nominal'] as num).toDouble(),
        tanggalSetor: json['tanggalSetor'] as int,
        status: json['status'] as String,
        catatanReview: json['catatanReview'] as String?,
        terakhirDijalankanPeriode: json['terakhirDijalankanPeriode'] as String?,
      );
}

// ── Arus kas pribadi ─────────────────────────────────────────────────────────
class CashFlowItem {
  const CashFlowItem({required this.tanggal, required this.kategori, required this.keterangan, required this.masuk, required this.nominal});
  final DateTime tanggal;
  final String kategori;
  final String keterangan;
  final bool masuk;
  final double nominal;
  factory CashFlowItem.fromJson(Map<String, dynamic> json) => CashFlowItem(
        tanggal: DateTime.parse(json['tanggal'] as String),
        kategori: json['kategori'] as String,
        keterangan: json['keterangan'] as String,
        masuk: json['arah'] == 'Masuk',
        nominal: (json['nominal'] as num).toDouble(),
      );
}

class PersonalCashFlow {
  const PersonalCashFlow({required this.totalMasuk, required this.totalKeluar, required this.saldoBersih, required this.riwayat});
  final double totalMasuk;
  final double totalKeluar;
  final double saldoBersih;
  final List<CashFlowItem> riwayat;
  factory PersonalCashFlow.fromJson(Map<String, dynamic> json) => PersonalCashFlow(
        totalMasuk: (json['totalMasuk'] as num).toDouble(),
        totalKeluar: (json['totalKeluar'] as num).toDouble(),
        saldoBersih: (json['saldoBersih'] as num).toDouble(),
        riwayat: (json['riwayat'] as List<dynamic>).map((e) => CashFlowItem.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

String _statusLabel(String status) => switch (status) {
      'Ditagih' => 'Menunggu konfirmasi',
      'Dibayar' || 'Lunas' => 'Lunas',
      'Diajukan' || 'MenungguPersetujuan' => 'Menunggu persetujuan',
      'Disetujui' || 'Selesai' => 'Disetujui',
      'Ditolak' => 'Ditolak',
      'Aktif' => 'Aktif (dana terkunci)',
      'JatuhTempo' => 'Jatuh tempo',
      'Dicairkan' => 'Dicairkan',
      _ => status,
    };

Color _statusColor(BuildContext context, String status) => switch (status) {
      'Dibayar' || 'Disetujui' || 'Aktif' || 'Dicairkan' || 'Lunas' || 'Selesai' => KkcsColors.success,
      'Ditolak' || 'Dibatalkan' => KkcsColors.danger,
      'JatuhTempo' => KkcsColors.info,
      _ => KkcsColors.warning,
    };

Color _statusBgColor(BuildContext context, String status) => switch (status) {
      'Dibayar' || 'Disetujui' || 'Aktif' || 'Dicairkan' || 'Lunas' || 'Selesai' => KkcsColors.successBg,
      'Ditolak' || 'Dibatalkan' => KkcsColors.dangerBg,
      'JatuhTempo' => const Color(0xFFEFF6FF),
      _ => KkcsColors.warningBg,
    };

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    final bg = _statusBgColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

String _monthLabel(DateTime date) {
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  return '${date.day} ${names[date.month - 1]} ${date.year}';
}

class MembershipStatusPage extends StatefulWidget {
  const MembershipStatusPage({required this.auth, required this.user, super.key});

  final AuthService auth;
  final AuthUser user;

  @override
  State<MembershipStatusPage> createState() => _MembershipStatusPageState();
}

class _MembershipStatusPageState extends State<MembershipStatusPage> {
  bool _checking = false;

  Future<void> _refresh() async {
    setState(() => _checking = true);
    try {
      final session = await widget.auth.restoreSession();
      if (!mounted) return;
      if (session != null && session.user.anggotaAktif) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => HomePage(auth: widget.auth, session: session)),
          (_) => false,
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pendaftaran masih ditinjau pengurus.')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _logout() async {
    await widget.auth.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LandingPage(auth: widget.auth)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ditolak = widget.user.statusKeanggotaan == 'Ditolak';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ditolak ? Icons.cancel_outlined : Icons.hourglass_top_outlined,
                    size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 20),
                Text(
                  ditolak ? 'Pendaftaran ditolak' : 'Menunggu persetujuan pengurus',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  ditolak
                      ? 'Silakan hubungi pengurus koperasi untuk informasi lebih lanjut.'
                      : 'Akun Anda akan aktif setelah pengurus menyetujui pendaftaran dan menyetorkan simpanan pokok Rp 100.000.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 28),
                if (!ditolak)
                  FilledButton.icon(
                    onPressed: _checking ? null : _refresh,
                    icon: _checking
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    label: const Text('Periksa status'),
                  ),
                const SizedBox(height: 10),
                TextButton(onPressed: _logout, child: const Text('Keluar')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SavingsTab extends StatefulWidget {
  const SavingsTab({required this.session, super.key});

  final AuthSession session;

  @override
  State<SavingsTab> createState() => _SavingsTabState();
}

class _SavingsTabState extends State<SavingsTab> {
  bool _loading = true;
  String? _error;
  bool _busy = false;
  SavingsOverview? _data;
  SukarelaRutinInfo? _rutin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([AuthService().fetchSavings(), AuthService().fetchSukarelaRutin()]);
      if (!mounted) return;
      setState(() {
        _data = results[0] as SavingsOverview;
        _rutin = results[1] as SukarelaRutinInfo?;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitSukarelaRutin() async {
    final nominalController = TextEditingController();
    var tanggalSetor = 1;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Ajukan Sukarela Rutin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sistem akan menyetor otomatis tiap bulan sampai Anda mengajukan berhenti dan disetujui pengurus.',
                style: TextStyle(fontSize: 12, color: KkcsColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nominalController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nominal per bulan', prefixText: 'Rp '),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: tanggalSetor,
                decoration: const InputDecoration(labelText: 'Tanggal setor tiap bulan'),
                items: [for (var d = 1; d <= 28; d++) DropdownMenuItem(value: d, child: Text('Tanggal $d'))],
                onChanged: (value) => setDialogState(() => tanggalSetor = value ?? 1),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Ajukan')),
          ],
        ),
      ),
    );
    if (result != true) return;
    final nominal = double.tryParse(nominalController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
    if (nominal <= 0) return;

    setState(() => _busy = true);
    try {
      await AuthService().submitSukarelaRutin(nominal: nominal, tanggalSetor: tanggalSetor);
      if (!mounted) return;
      _toast('Pengajuan Sukarela Rutin terkirim. Menunggu persetujuan pengurus.');
      await _load();
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopSukarelaRutin(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajukan berhenti Sukarela Rutin'),
        content: const Text('Setoran otomatis bulanan akan dihentikan setelah pengurus menyetujui pengajuan ini.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Ajukan Berhenti')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await AuthService().stopSukarelaRutin(id);
      if (!mounted) return;
      _toast('Pengajuan berhenti terkirim. Menunggu persetujuan pengurus.');
      await _load();
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message.replaceFirst('Exception: ', ''))));
  }

  Future<void> _submitSukarela(String jenis) async {
    final controller = TextEditingController();
    final nominal = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(jenis == 'Tarik' ? 'Tarik simpanan sukarela' : 'Setor simpanan sukarela'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Ajukan'),
          ),
        ],
      ),
    );
    if (nominal == null || nominal <= 0) return;

    PlatformFile? bukti;
    if (jenis == 'Setor') {
      if (!mounted) return;
      bukti = await pickBuktiTransfer(context);
      if (bukti == null) return;
    }

    setState(() => _busy = true);
    try {
      await AuthService().requestSukarela(jenis: jenis, nominal: nominal, bukti: bukti);
      if (!mounted) return;
      _toast('Pengajuan terkirim. Menunggu persetujuan pengurus.');
      await _load();
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ajukanBerjangka(BerjangkaProduct produk) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajukan simpanan berjangka'),
        content: Text(
          '${produk.nama}\nNominal ${formatRupiah(produk.nominal)} · terkunci ${produk.tenorBulan} bulan.\n\n'
          'Dana tidak dapat ditarik sebelum jatuh tempo. Pengajuan diverifikasi pengurus.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Ajukan')),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final bukti = await pickBuktiTransfer(context);
    if (bukti == null) return;

    setState(() => _busy = true);
    try {
      await AuthService().requestBerjangka(produkId: produk.id, bukti: bukti);
      if (!mounted) return;
      _toast('Pengajuan simpanan berjangka terkirim.');
      await _load();
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ajukanPencairan(TermDeposit deposit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajukan pencairan dipercepat'),
        content: Text(
          '${deposit.produkNama} · ${formatRupiah(deposit.nominal)}\n\n'
          'Jika dicairkan sebelum jatuh tempo, Anda hanya menerima pokok — '
          'bunga ${formatRupiah(deposit.estimasiBunga)} TIDAK dibayarkan. '
          'Pengajuan diverifikasi pengurus.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Ajukan pencairan')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await AuthService().requestEarlyWithdrawal(berjangkaId: deposit.id);
      if (!mounted) return;
      _toast('Pengajuan pencairan dipercepat terkirim.');
      await _load();
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simpanan Saya',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: KkcsColors.primaryDeep,
                        letterSpacing: -0.3,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pokok, wajib, sukarela, dan berjangka dalam satu tempat.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: KkcsColors.textSecondary,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
          if (_loading) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator(minHeight: 2)),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (data != null) ...[
            _SavingsBalanceCard(
              icon: Icons.verified_user_outlined,
              title: 'Simpanan Pokok',
              saldo: data.pokok.saldo,
              caption: 'Setoran wajib keanggotaan. Tidak dapat ditarik selama menjadi anggota.',
            ),
            const SizedBox(height: 14),
            _AccountSectionCard(
              icon: Icons.event_repeat_outlined,
              title: 'Simpanan Wajib',
              subtitle: 'Ditagih otomatis setiap tanggal ${data.wajib.tanggalTagih}.',
              children: [
                _InfoRow(label: 'Saldo terkumpul', value: formatRupiah(data.wajib.saldo)),
                _InfoRow(label: 'Nominal per bulan', value: formatRupiah(data.wajib.nominalBulanan)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: KkcsColors.borderSubtle),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: KkcsColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pembayaran dikonfirmasi pengurus koperasi (potong gaji / setor tunai).',
                          style: TextStyle(fontSize: 11.5, color: KkcsColors.textSecondary, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (data.wajib.tagihan.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('Belum ada riwayat tagihan.', style: TextStyle(fontSize: 12.5, color: KkcsColors.textMuted)),
                  )
                else ...[
                  const Text('Riwayat Tagihan Bulanan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.textPrimary)),
                  const SizedBox(height: 6),
                  ...data.wajib.tagihan.take(6).map((bill) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: KkcsColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: KkcsColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.calendar_month_outlined, size: 16, color: KkcsColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Periode ${bill.periode}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.textPrimary)),
                                  Text(formatRupiah(bill.nominal), style: const TextStyle(fontSize: 12, color: KkcsColors.textSecondary)),
                                ],
                              ),
                            ),
                            _StatusBadge(status: bill.status),
                          ],
                        ),
                      )),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _AccountSectionCard(
              icon: Icons.volunteer_activism_outlined,
              title: 'Simpanan Sukarela',
              subtitle: 'Bunga ${(data.sukarela.bungaTahunan * 100).toStringAsFixed(2)}%/th, dihitung saldo harian, dipotong PPh ${(data.sukarela.tarifPphBunga * 100).toStringAsFixed(0)}%, dibukukan tanggal akhir tiap bulan.',
              children: [
                _InfoRow(label: 'Saldo sukarela saat ini', value: formatRupiah(data.sukarela.saldo)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _submitSukarela('Setor'),
                      style: FilledButton.styleFrom(
                        backgroundColor: KkcsColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Setor Sukarela', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _submitSukarela('Tarik'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KkcsColors.primaryDeep,
                        side: const BorderSide(color: KkcsColors.primary, width: 1.4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: const Text('Tarik Sukarela', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
                if (data.sukarela.pengajuan.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Pengajuan Terakhir', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.textPrimary)),
                  const SizedBox(height: 6),
                  ...data.sukarela.pengajuan.take(5).map((req) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: KkcsColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              req.jenis == 'Tarik' ? Icons.arrow_circle_up_outlined : Icons.arrow_circle_down_outlined,
                              size: 18,
                              color: req.jenis == 'Tarik' ? KkcsColors.danger : KkcsColors.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${req.jenis} ${formatRupiah(req.nominal)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            ),
                            _StatusBadge(status: req.status),
                          ],
                        ),
                      )),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _AccountSectionCard(
              icon: Icons.autorenew_outlined,
              title: 'Sukarela Rutin',
              subtitle: 'Setoran sukarela otomatis tiap bulan, tidak perlu diajukan manual setiap kali.',
              children: [
                if (_rutin == null) ...[
                  const Text(
                    'Belum ada instruksi Sukarela Rutin. Ajukan sekali, sistem akan menyetor otomatis tiap bulan.',
                    style: TextStyle(fontSize: 12.5, color: KkcsColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _submitSukarelaRutin,
                    style: FilledButton.styleFrom(
                      backgroundColor: KkcsColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Ajukan Sukarela Rutin', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: _InfoRow(label: 'Nominal per bulan', value: formatRupiah(_rutin!.nominal))),
                      _StatusBadge(status: _rutin!.status),
                    ],
                  ),
                  _InfoRow(label: 'Tanggal setor', value: 'Tanggal ${_rutin!.tanggalSetor}'),
                  if (_rutin!.terakhirDijalankanPeriode != null)
                    _InfoRow(label: 'Terakhir berjalan', value: _rutin!.terakhirDijalankanPeriode!),
                  if (_rutin!.status == 'DihentikanDiajukan')
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Pengajuan berhenti sedang menunggu persetujuan pengurus.',
                          style: TextStyle(fontSize: 12, color: KkcsColors.textSecondary)),
                    ),
                  if (_rutin!.status == 'Aktif') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _stopSukarelaRutin(_rutin!.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KkcsColors.danger,
                        side: const BorderSide(color: KkcsColors.danger, width: 1.4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('Ajukan Berhenti', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ],
            ),
            const SizedBox(height: 14),
            _AccountSectionCard(
              icon: Icons.lock_clock_outlined,
              title: 'Simpanan Berjangka',
              subtitle: 'Bunga ${(data.berjangka.bungaTahunan * 100).toStringAsFixed(2)}%/th. Dana terkunci hingga jatuh tempo.',
              children: [
                if (data.berjangka.produk.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('Belum ada paket berjangka tersedia.', style: TextStyle(fontSize: 12.5, color: KkcsColors.textMuted)),
                  )
                else
                  ...data.berjangka.produk.map((produk) {
                    final bunga = produk.nominal * data.berjangka.bungaTahunan * produk.tenorBulan / 12;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: KkcsColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  produk.nama,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: KkcsColors.primaryDeep),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: KkcsColors.primaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${produk.tenorBulan} Bulan', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: KkcsColors.primary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Nominal Pokok', style: TextStyle(fontSize: 11, color: KkcsColors.textSecondary)),
                                  Text(formatRupiah(produk.nominal), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.textPrimary)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Estimasi Bunga', style: TextStyle(fontSize: 11, color: KkcsColors.textSecondary)),
                                  Text(formatRupiah(bunga), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.success)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: _busy ? null : () => _ajukanBerjangka(produk),
                            style: FilledButton.styleFrom(
                              backgroundColor: KkcsColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(36),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Ajukan Simpanan Berjangka', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  }),
                if (data.berjangka.milikSaya.isNotEmpty) ...[
                  const Divider(height: 24, color: KkcsColors.borderSubtle),
                  const Text('Simpanan Berjangka Aktif & Riwayat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: KkcsColors.textPrimary)),
                  const SizedBox(height: 6),
                  ...data.berjangka.milikSaya.map((deposit) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: KkcsColors.borderSubtle),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Text(
                                '${deposit.produkNama} · ${formatRupiah(deposit.nominal)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.textPrimary),
                              ),
                            ),
                            _StatusBadge(status: deposit.status),
                          ]),
                          const SizedBox(height: 4),
                          if (deposit.tanggalJatuhTempo != null)
                            Text('Jatuh tempo: ${_monthLabel(deposit.tanggalJatuhTempo!)}',
                                style: const TextStyle(fontSize: 12, color: KkcsColors.textSecondary)),
                          Text(
                            deposit.bungaDibayar != null
                                ? (deposit.bungaDibayar == 0
                                    ? 'Dicairkan dipercepat — tanpa bunga'
                                    : 'Bunga dibayar ${formatRupiah(deposit.bungaDibayar!)} (masuk ke sukarela)')
                                : 'Estimasi bunga saat jatuh tempo: ${formatRupiah(deposit.estimasiBunga)}',
                            style: const TextStyle(fontSize: 12, color: KkcsColors.textSecondary),
                          ),
                          if (deposit.status == 'Aktif') ...[
                            const SizedBox(height: 8),
                            if (deposit.pencairanDiajukan)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: KkcsColors.warningBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: KkcsColors.warning.withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.hourglass_top_outlined, size: 15, color: KkcsColors.warning),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Pengajuan pencairan dipercepat menunggu persetujuan pengurus.',
                                        style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w600, fontSize: 11.5),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: _busy ? null : () => _ajukanPencairan(deposit),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: KkcsColors.danger,
                                  side: const BorderSide(color: KkcsColors.danger),
                                  minimumSize: const Size.fromHeight(34),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.lock_open_outlined, size: 15),
                                label: const Text('Ajukan pencairan dipercepat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ]),
                      )),
                ],
              ],
            ),
            if (data.mutasi.isNotEmpty) ...[
              const SizedBox(height: 14),
              _AccountSectionCard(
                icon: Icons.receipt_long_outlined,
                title: 'Mutasi Terakhir',
                subtitle: 'Riwayat transaksi simpanan.',
                children: data.mutasi
                    .take(10)
                    .map((m) {
                      final debit = m.jenis == 'Tarik' || m.jenis == 'Pajak';
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: debit ? KkcsColors.dangerBg : KkcsColors.successBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                debit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                size: 16,
                                color: debit ? KkcsColors.danger : KkcsColors.success,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${m.rekening} · ${m.jenis}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: KkcsColors.textPrimary)),
                                  Text(_monthLabel(m.tanggal), style: const TextStyle(fontSize: 11, color: KkcsColors.textMuted)),
                                ],
                              ),
                            ),
                            Text(
                              '${debit ? '-' : '+'}${formatRupiah(m.nominal)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: debit ? KkcsColors.danger : KkcsColors.success,
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SavingsBalanceCard extends StatelessWidget {
  const _SavingsBalanceCard({required this.icon, required this.title, required this.saldo, required this.caption});

  final IconData icon;
  final String title;
  final double saldo;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: KkcsColors.heroGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: KkcsColors.primaryDeep.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFFA5F3FC), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            formatRupiah(saldo),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            style: const TextStyle(color: Color(0xFFE0F2FE), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user, required this.radius});

  final AuthUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.fotoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: KkcsColors.mint,
      backgroundImage: photoUrl == null ? null : NetworkImage('${AuthService.baseUrl}$photoUrl'),
      child: photoUrl == null
          ? Text(
              user.namaLengkap[0].toUpperCase(),
              style: TextStyle(color: KkcsColors.primaryDeep, fontSize: radius * .75, fontWeight: FontWeight.bold),
            )
          : null,
    );
  }
}

class _PersonalDataCard extends StatelessWidget {
  const _PersonalDataCard({
    required this.user,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.addressController,
    required this.isEditing,
    required this.saving,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
  });

  final AuthUser user;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final bool isEditing;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: isEditing ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: _buildViewMode(context),
          secondChild: _buildEditMode(context),
        ),
      ),
    );
  }

  Widget _buildViewMode(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: KkcsColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_outline, size: 20, color: KkcsColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Data pribadi', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Informasi profil dan kontak Anda', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: KkcsColors.textSecondary)),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onEdit,
              style: FilledButton.styleFrom(
                backgroundColor: KkcsColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
              label: const Text('Edit Profil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KkcsColors.border),
          ),
          child: Column(
            children: [
              _ProfileDetailItem(
                icon: Icons.person_outline,
                label: 'Nama Lengkap',
                value: user.namaLengkap,
              ),
              const Divider(height: 1, indent: 52, endIndent: 16, color: Color(0xFFE2E8F0)),
              _ProfileDetailItem(
                icon: Icons.badge_outlined,
                label: 'Nomor Induk Karyawan (NIK)',
                value: user.nomorIndukKaryawan,
                badge: user.statusKeanggotaan,
              ),
              const Divider(height: 1, indent: 52, endIndent: 16, color: Color(0xFFE2E8F0)),
              _ProfileDetailItem(
                icon: Icons.mail_outline,
                label: 'Alamat Email',
                value: (user.email != null && user.email!.trim().isNotEmpty) ? user.email! : null,
                placeholder: 'Belum diisi',
              ),
              const Divider(height: 1, indent: 52, endIndent: 16, color: Color(0xFFE2E8F0)),
              _ProfileDetailItem(
                icon: Icons.phone_outlined,
                label: 'Nomor Telepon / WhatsApp',
                value: (user.nomorTelepon != null && user.nomorTelepon!.trim().isNotEmpty) ? user.nomorTelepon! : null,
                placeholder: 'Belum diisi',
              ),
              const Divider(height: 1, indent: 52, endIndent: 16, color: Color(0xFFE2E8F0)),
              _ProfileDetailItem(
                icon: Icons.location_on_outlined,
                label: 'Alamat Domisili',
                value: (user.alamat != null && user.alamat!.trim().isNotEmpty) ? user.alamat! : null,
                placeholder: 'Belum diisi',
                isMultiLine: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditMode(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: KkcsColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_note_rounded, size: 22, color: KkcsColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit data pribadi', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Perbarui nama, kontak & alamat Anda', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: KkcsColors.textSecondary)),
                ],
              ),
            ),
            IconButton(
              onPressed: saving ? null : onCancel,
              icon: const Icon(Icons.close, size: 20, color: KkcsColors.textSecondary),
              tooltip: 'Batal edit',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: KkcsColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 16, color: KkcsColors.textSecondary),
              const SizedBox(width: 8),
              Text('NIK: ${user.nomorIndukKaryawan}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.primaryDeep)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: KkcsColors.border),
                ),
                child: const Text('Terkunci', style: TextStyle(fontSize: 10.5, color: KkcsColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nama lengkap *',
            prefixIcon: Icon(Icons.badge_outlined, size: 20, color: KkcsColors.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.mail_outline, size: 20, color: KkcsColors.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Nomor telepon / WhatsApp',
            prefixIcon: Icon(Icons.phone_outlined, size: 20, color: KkcsColors.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: addressController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Alamat domisili',
            prefixIcon: Icon(Icons.location_on_outlined, size: 20, color: KkcsColors.textSecondary),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: saving ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Batal', style: TextStyle(color: KkcsColors.textSecondary, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(saving ? 'Menyimpan...' : 'Simpan perubahan'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileDetailItem extends StatelessWidget {
  const _ProfileDetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.placeholder,
    this.badge,
    this.isMultiLine = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? placeholder;
  final String? badge;
  final bool isMultiLine;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: KkcsColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: KkcsColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: KkcsColors.textSecondary),
                ),
                const SizedBox(height: 2.5),
                Text(
                  hasValue ? value! : (placeholder ?? '—'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                    fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                    color: hasValue ? KkcsColors.primaryDeep : KkcsColors.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: KkcsColors.successBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: KkcsColors.success.withValues(alpha: 0.3)),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: KkcsColors.success,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileShuCard extends StatelessWidget {
  const _ProfileShuCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KkcsColors.border),
        boxShadow: [
          BoxShadow(
            color: KkcsColors.primaryDeep.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: KkcsColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF99F6E4)),
                  ),
                  child: const Icon(Icons.auto_graph_rounded, color: KkcsColors.primaryDark, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'SHU Saya',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: KkcsColors.primaryDeep,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: KkcsColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Dividen Anggota',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: KkcsColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Rincian pembagian SHU, jasa modal & usaha',
                        style: TextStyle(fontSize: 12, color: KkcsColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: KkcsColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Buka',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordCard extends StatefulWidget {
  const _ChangePasswordCard({required this.auth, required this.onSuccess});

  final AuthService auth;
  final VoidCallback onSuccess;

  @override
  State<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<_ChangePasswordCard> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isEditing = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _cancel() {
    setState(() {
      _isEditing = false;
      _error = null;
      _oldController.clear();
      _newController.clear();
      _confirmController.clear();
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.auth.changePassword(passwordLama: _oldController.text, passwordBaru: _newController.text);
      if (!mounted) return;
      _oldController.clear();
      _newController.clear();
      _confirmController.clear();
      setState(() => _isEditing = false);
      widget.onSuccess();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _isEditing ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: _buildViewMode(context),
          secondChild: _buildEditMode(context),
        ),
      ),
    );
  }

  Widget _buildViewMode(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: KkcsColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_outlined, size: 20, color: KkcsColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Keamanan & kata sandi', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Kelola keamanan dan kata sandi akun Anda', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: KkcsColors.textSecondary)),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              style: FilledButton.styleFrom(
                backgroundColor: KkcsColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.key_outlined, size: 14, color: Colors.white),
              label: const Text('Ganti Sandi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: KkcsColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: KkcsColors.successBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.check_circle_outline, size: 16, color: KkcsColors.success),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kata Sandi Terproteksi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KkcsColors.primaryDeep)),
                    SizedBox(height: 1.5),
                    Text('Disarankan mengganti sandi secara berkala', style: TextStyle(fontSize: 11, color: KkcsColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditMode(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: KkcsColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_reset_outlined, size: 20, color: KkcsColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ganti password', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Perbarui kata sandi untuk mengamankan akun', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: KkcsColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _saving ? null : _cancel,
                icon: const Icon(Icons.close, size: 20, color: KkcsColors.textSecondary),
                tooltip: 'Batal',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: KkcsColors.dangerBg, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: KkcsColors.danger),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: KkcsColors.danger, fontSize: 12.5))),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _oldController,
            obscureText: _obscureOld,
            decoration: InputDecoration(
              labelText: 'Password saat ini',
              prefixIcon: const Icon(Icons.lock_outline, size: 20, color: KkcsColors.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(_obscureOld ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureOld = !_obscureOld),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _newController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: 'Password baru',
              prefixIcon: const Icon(Icons.key_outlined, size: 20, color: KkcsColors.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Wajib diisi';
              if (v.length < 8) return 'Minimal 8 karakter';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Konfirmasi password baru',
              prefixIcon: const Icon(Icons.check_circle_outline, size: 20, color: KkcsColors.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) => v != _newController.text ? 'Konfirmasi tidak sama dengan password baru' : null,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: _saving ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Batal', style: TextStyle(color: KkcsColors.textSecondary, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_reset_outlined, size: 18),
                  label: Text(_saving ? 'Menyimpan...' : 'Ganti password'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashFlowCard extends StatefulWidget {
  const _CashFlowCard({required this.loading, required this.error, required this.data, required this.onRefresh});

  final bool loading;
  final String? error;
  final PersonalCashFlow? data;
  final Future<void> Function() onRefresh;

  @override
  State<_CashFlowCard> createState() => _CashFlowCardState();
}

class _CashFlowCardState extends State<_CashFlowCard> {
  bool _showAll = false;

  IconData _iconFor(String kategori) => switch (kategori) {
        'Simpanan' => Icons.savings_outlined,
        'Pinjaman' => Icons.request_quote_outlined,
        'Katalog' => Icons.storefront_outlined,
        _ => Icons.swap_horiz,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final data = widget.data;
    final riwayat = data?.riwayat ?? const <CashFlowItem>[];
    final tampil = _showAll ? riwayat : riwayat.take(6).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: KkcsColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: KkcsColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Arus kas pribadi', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Mutasi simpanan, pinjaman & belanja Anda', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.loading ? null : () => widget.onRefresh(),
                icon: widget.loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 20, color: KkcsColors.textSecondary),
                tooltip: 'Muat ulang',
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.error != null)
            Text(widget.error!, style: TextStyle(color: colors.error))
          else if (data == null && widget.loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: CircularProgressIndicator()))
          else if (data != null) ...[
            Row(children: [
              Expanded(child: _CashFlowStat(label: 'Masuk', value: data.totalMasuk, color: KkcsColors.success, icon: Icons.arrow_downward)),
              const SizedBox(width: 8),
              Expanded(child: _CashFlowStat(label: 'Keluar', value: data.totalKeluar, color: KkcsColors.danger, icon: Icons.arrow_upward)),
              const SizedBox(width: 8),
              Expanded(child: _CashFlowStat(label: 'Bersih', value: data.saldoBersih, color: KkcsColors.primary, icon: Icons.account_balance_wallet_outlined)),
            ]),
            const SizedBox(height: 12),
            if (riwayat.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('Belum ada aktivitas keuangan tercatat.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
              )
            else ...[
              const Divider(height: 20),
              ...tampil.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: (item.masuk ? KkcsColors.success : KkcsColors.danger).withValues(alpha: .1),
                        child: Icon(_iconFor(item.kategori), size: 16, color: item.masuk ? KkcsColors.success : KkcsColors.danger),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.keterangan, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(_monthLabel(item.tanggal), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black45, fontSize: 11)),
                        ]),
                      ),
                      Text(
                        '${item.masuk ? '+' : '−'}${formatRupiah(item.nominal)}',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: item.masuk ? KkcsColors.success : KkcsColors.danger),
                      ),
                    ]),
                  )),
              if (riwayat.length > 6)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    child: Text(_showAll ? 'Tampilkan lebih sedikit' : 'Lihat semua (${riwayat.length})'),
                  ),
                ),
            ],
          ],
        ]),
      ),
    );
  }
}

class _CashFlowStat extends StatelessWidget {
  const _CashFlowStat({required this.label, required this.value, required this.color, required this.icon});

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        Text(formatRupiah(value), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: color)),
      ]),
    );
  }
}

class _AccountSectionCard extends StatelessWidget {
  const _AccountSectionCard({required this.icon, required this.title, required this.subtitle, required this.children});

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: KkcsColors.borderSubtle, width: 1.2),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: KkcsColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: KkcsColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: KkcsColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: KkcsColors.textSecondary, height: 1.25)),
            ])),
          ]),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: KkcsColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: KkcsColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ]),
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({required this.auth, required this.session, super.key});

  final AuthService auth;
  final AuthSession session;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late AuthUser _user;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  bool _savingProfile = false;
  bool _uploadingPhoto = false;
  bool _isEditingProfile = false;

  bool _loadingCashFlow = true;
  String? _cashFlowError;
  PersonalCashFlow? _cashFlow;

  @override
  void initState() {
    super.initState();
    _user = widget.session.user;
    _nameController = TextEditingController(text: _user.namaLengkap);
    _emailController = TextEditingController(text: _user.email ?? '');
    _phoneController = TextEditingController(text: _user.nomorTelepon ?? '');
    _addressController = TextEditingController(text: _user.alamat ?? '');
    _loadCashFlow();
  }

  Future<void> _loadCashFlow() async {
    setState(() {
      _loadingCashFlow = true;
      _cashFlowError = null;
    });
    try {
      final data = await AuthService().fetchCashFlow();
      if (!mounted) return;
      setState(() => _cashFlow = data);
    } catch (error) {
      if (!mounted) return;
      setState(() => _cashFlowError = error is ApiException ? error.message : 'Gagal memuat arus kas.');
    } finally {
      if (mounted) setState(() => _loadingCashFlow = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    await widget.auth.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LandingPage(auth: widget.auth)),
      (_) => false,
    );
  }

  void _startEditProfile() {
    setState(() {
      _nameController.text = _user.namaLengkap;
      _emailController.text = _user.email ?? '';
      _phoneController.text = _user.nomorTelepon ?? '';
      _addressController.text = _user.alamat ?? '';
      _isEditingProfile = true;
    });
  }

  void _cancelEditProfile() {
    setState(() {
      _nameController.text = _user.namaLengkap;
      _emailController.text = _user.email ?? '';
      _phoneController.text = _user.nomorTelepon ?? '';
      _addressController.text = _user.alamat ?? '';
      _isEditingProfile = false;
    });
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Nama lengkap tidak boleh kosong.');
      return;
    }
    setState(() => _savingProfile = true);
    try {
      final user = await widget.auth.updateProfile(
        namaLengkap: _nameController.text.trim(),
        email: _emailController.text.trim(),
        nomorTelepon: _phoneController.text.trim(),
        alamat: _addressController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _user = user;
        _isEditingProfile = false;
      });
      _showMessage('Data pribadi berhasil diperbarui.');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final photo = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1200);
    if (photo == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final user = await widget.auth.uploadProfilePhoto(photo);
      if (!mounted) return;
      setState(() => _user = user);
      _showMessage('Foto profil berhasil diperbarui.');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Pilih dari galeri'), onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.gallery); }),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Ambil foto'), onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.camera); }),
        ]),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message.replaceFirst('Exception: ', ''))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akun saya')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: KkcsColors.heroGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: KkcsColors.primaryDeep.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _ProfileAvatar(user: _user, radius: 36),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -2,
                        child: Material(
                          color: KkcsColors.primary,
                          shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2)),
                          elevation: 2,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _uploadingPhoto ? null : _showPhotoOptions,
                            child: Padding(
                              padding: const EdgeInsets.all(7),
                              child: _uploadingPhoto
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.camera_alt, size: 15, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _user.namaLengkap,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.badge_outlined, size: 13, color: Color(0xFFA5F3FC)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'NIK: ${_user.nomorIndukKaryawan}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: KkcsColors.successBg.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified, size: 12, color: KkcsColors.success),
                                  const SizedBox(width: 4),
                                  Text(
                                    _user.statusKeanggotaan,
                                    style: const TextStyle(color: KkcsColors.success, fontSize: 11, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_user.email != null && _user.email!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.mail_outline, size: 13, color: Colors.white.withValues(alpha: 0.75)),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _user.email!,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _PersonalDataCard(
              user: _user,
              nameController: _nameController,
              emailController: _emailController,
              phoneController: _phoneController,
              addressController: _addressController,
              isEditing: _isEditingProfile,
              saving: _savingProfile,
              onEdit: _startEditProfile,
              onCancel: _cancelEditProfile,
              onSave: _saveProfile,
            ),
            const SizedBox(height: 18),
            _ProfileShuCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ShuSayaPage(session: widget.session)),
              ),
            ),
            const SizedBox(height: 18),
            _ChangePasswordCard(auth: widget.auth, onSuccess: () => _showMessage('Password berhasil diganti.')),
            const SizedBox(height: 18),
            _CashFlowCard(loading: _loadingCashFlow, error: _cashFlowError, data: _cashFlow, onRefresh: _loadCashFlow),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KkcsColors.danger.withValues(alpha: 0.2)),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onTap: () => _logout(context),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: KkcsColors.dangerBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded, size: 18, color: KkcsColors.danger),
                ),
                title: const Text('Keluar dari akun', style: TextStyle(fontWeight: FontWeight.w700, color: KkcsColors.danger, fontSize: 14)),
                subtitle: const Text('Akhiri sesi login aplikasi di perangkat ini', style: TextStyle(fontSize: 11.5, color: KkcsColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: KkcsColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KkcsColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: KkcsColors.border),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 20, color: KkcsColors.primaryDeep),
                  ),
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: KkcsColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: KkcsColors.primaryDeep.withValues(alpha: 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _BrandMark(size: 48),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: KkcsColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: KkcsColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shield_outlined, size: 13, color: KkcsColors.primary),
                                  SizedBox(width: 5),
                                  Text(
                                    'KKCS Mobile',
                                    style: TextStyle(
                                      color: KkcsColors.primaryDeep,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: KkcsColors.primaryDeep,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: KkcsColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        child,
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 14, color: KkcsColors.textDisabled),
                      SizedBox(width: 6),
                      Text(
                        'Akses aman terenkripsi • Portal Anggota KKCS',
                        style: TextStyle(fontSize: 11.5, color: KkcsColors.textMuted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * .28),
          border: Border.all(color: KkcsColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: KkcsColors.primaryDeep.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: EdgeInsets.all(size * .12),
        child: Image.asset('assets/logo_kkcs.png', fit: BoxFit.contain),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: KkcsColors.dangerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KkcsColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: KkcsColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(
                color: KkcsColors.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonLoader extends StatelessWidget {
  const _ButtonLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}

String? _requiredNik(String? value) {
  if (value == null || value.trim().isEmpty) return 'NIK wajib diisi';
  if (value.trim().length < 5) return 'NIK minimal 5 karakter';
  return null;
}
