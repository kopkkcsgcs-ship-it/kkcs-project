import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kkcs/main.dart';

void main() {
  testWidgets('landing page menyediakan akses masuk dan daftar', (WidgetTester tester) async {
    final auth = AuthService();
    await tester.pumpWidget(MaterialApp(home: LandingPage(auth: auth)));

    expect(find.text('Layanan koperasi\ndalam satu ruang.'), findsOneWidget);
    expect(find.text('Masuk ke akun'), findsOneWidget);
    expect(find.text('Buat akun baru'), findsOneWidget);
  });

  testWidgets('beranda menampilkan portal mandiri anggota dan navigasi', (WidgetTester tester) async {
    const session = AuthSession(
      token: 'test-token',
      user: AuthUser(id: 1, namaLengkap: 'Test User', nomorIndukKaryawan: 'NIK-001', email: 'test@example.com'),
    );
    await tester.pumpWidget(MaterialApp(home: HomePage(auth: AuthService(), session: session)));

    expect(find.text('Beranda KKCS'), findsOneWidget);
    expect(find.byTooltip('Akun saya'), findsOneWidget);
    expect(find.text('Portal Mandiri Anggota'), findsOneWidget);
    expect(find.text('Ringkasan keuangan'), findsOneWidget);
    expect(find.text('Total simpanan'), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Simpan Pinjam'), findsOneWidget);
    expect(find.text('Katalog'), findsOneWidget);
    expect(find.text('E-RAT'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('beranda navigasi ke halaman detail saat kartu ringkasan keuangan diklik', (WidgetTester tester) async {
    const session = AuthSession(
      token: 'test-token',
      user: AuthUser(id: 1, namaLengkap: 'Test User', nomorIndukKaryawan: 'NIK-001', email: 'test@example.com'),
    );
    await tester.pumpWidget(MaterialApp(home: HomePage(auth: AuthService(), session: session)));

    // 1. Klik kartu Total simpanan
    await tester.tap(find.text('Total simpanan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Rincian Total Simpanan'), findsOneWidget);

    // Kembali ke beranda
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 2. Klik kartu Pinjaman aktif
    await tester.tap(find.text('Pinjaman aktif'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Detail Pinjaman Aktif'), findsOneWidget);

    // Kembali ke beranda
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 3. Klik kartu Cicilan berjalan
    await tester.tap(find.text('Cicilan berjalan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Detail Cicilan Berjalan'), findsOneWidget);

    // Kembali ke beranda
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 4. Klik kartu Estimasi SHU
    await tester.tap(find.textContaining('Estimasi SHU'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('SHU Saya'), findsOneWidget);
  });

  testWidgets('modul E-RAT menampilkan voting dan laporan tahunan', (WidgetTester tester) async {
    const session = AuthSession(
      token: 'test-token',
      user: AuthUser(id: 1, namaLengkap: 'Test User', nomorIndukKaryawan: 'NIK-001', email: 'test@example.com'),
    );
    await tester.pumpWidget(MaterialApp(home: EratPage(session: session)));

    expect(find.text('Partisipasi E-RAT'), findsOneWidget);
    expect(find.text('Rapat Anggota Tahunan Digital'), findsOneWidget);
    expect(find.text('Voting'), findsOneWidget);
  });

  testWidgets('modul simpan pinjam menampilkan tab simpanan dan pinjaman', (WidgetTester tester) async {
    const session = AuthSession(
      token: 'test-token',
      user: AuthUser(id: 1, namaLengkap: 'Test User', nomorIndukKaryawan: 'NIK-001', email: 'test@example.com'),
    );
    await tester.pumpWidget(MaterialApp(home: DigitalSavingsLoanPage(session: session)));

    expect(find.text('Simpanan & Pinjaman Digital'), findsOneWidget);
    expect(find.text('Simpanan'), findsOneWidget);
    expect(find.text('Pinjaman'), findsOneWidget);
  });

  testWidgets('modul unit usaha menampilkan katalog produk koperasi', (WidgetTester tester) async {
    const session = AuthSession(
      token: 'test-token',
      user: AuthUser(id: 1, namaLengkap: 'Test User', nomorIndukKaryawan: 'NIK-001', email: 'test@example.com'),
    );
    await tester.pumpWidget(MaterialApp(home: BusinessUnitPage(session: session)));

    expect(find.text('Katalog Produk Koperasi'), findsNWidgets(2));
    expect(find.text('Jual produk ke koperasi'), findsOneWidget);
    expect(find.text('Ajukan produk baru'), findsOneWidget);
  });

  testWidgets('akun menampilkan aksi manajemen anggota dan logout', (WidgetTester tester) async {
    const session = AuthSession(
      token: 'test-token',
      user: AuthUser(id: 1, namaLengkap: 'Test User', nomorIndukKaryawan: 'NIK-001', email: 'test@example.com'),
    );
    await tester.pumpWidget(MaterialApp(home: AccountPage(auth: AuthService(), session: session)));

    expect(find.text('Akun saya'), findsOneWidget);
    expect(find.text('Data pribadi'), findsOneWidget);
    expect(find.text('Edit Profil'), findsOneWidget);

    // Buka mode edit profil
    await tester.tap(find.text('Edit Profil'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Simpan perubahan'), findsOneWidget);

    // Batal edit profil via tombol header
    await tester.tap(find.byTooltip('Batal edit'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    expect(find.text('SHU Saya'), findsOneWidget);
    expect(find.text('Buka'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pump();
    expect(find.text('Keluar dari akun'), findsOneWidget);
  });
}
