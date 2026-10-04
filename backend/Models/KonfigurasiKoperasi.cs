public class KonfigurasiKoperasi
{
    public int Id { get; set; }

    // Saldo awal Simpanan Pokok yang dikreditkan saat pendaftaran anggota disetujui.
    public decimal SimpananPokokNominal { get; set; } = 100_000m;

    // Nominal Simpanan Wajib yang ditagih otomatis setiap bulan.
    public decimal SimpananWajibNominal { get; set; } = 50_000m;

    // Tanggal jatuh tempo tagihan Simpanan Wajib tiap bulan.
    public int TanggalTagihWajib { get; set; } = 25;

    // Suku bunga tahunan (fraksi, mis. 0.025 = 2,5%).
    public decimal BungaSukarelaTahunan { get; set; } = 0.025m;

    public decimal BungaDepositoTahunan { get; set; } = 0.045m;

    // PPh (final) yang dipotong dari nilai bruto sebelum dikreditkan/dibagikan ke anggota — berlaku
    // untuk bunga simpanan sukarela dan bunga simpanan berjangka (deposito).
    public decimal TarifPph { get; set; } = 0.20m;

    // PPh atas SHU yang diterima anggota (Jasa Modal + Jasa Usaha) — tarif tersendiri, terpisah dari
    // TarifPph di atas karena kebijakan RAT menetapkan SHU dipotong 15% dari penerimaan.
    public decimal TarifPphShu { get; set; } = 0.15m;

    // Catatan kaki yang ditampilkan di laporan Neraca (mis. asal saldo tertentu yang perlu dijelaskan).
    public string? CatatanNeraca { get; set; }

    public DateTime DiperbaruiPada { get; set; } = DateTime.UtcNow;
}
