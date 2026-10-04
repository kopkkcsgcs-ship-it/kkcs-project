using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace backend.Migrations
{
    /// <inheritdoc />
    public partial class TambahCatatanNeraca : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "CatatanNeraca",
                table: "KonfigurasiKoperasi",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.Sql(
                "UPDATE KonfigurasiKoperasi SET CatatanNeraca = N'Simpanan Pokok Rp500.000 pada Neraca berasal dari 5 eks-anggota yang sudah keluar (Kusnan, Hadi Sanyoto, Erma Bintri, Saring Saiman, Soesila Brata). Dicatat sebagai milik koperasi, bukan simpanan anggota aktif.' WHERE Id = 1;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CatatanNeraca",
                table: "KonfigurasiKoperasi");
        }
    }
}
