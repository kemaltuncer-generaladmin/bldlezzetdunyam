/**
 * İşletmenin ticari kimlik bilgileri (unvan, adres, vergi dairesi/no, MERSİS,
 * KEP, telefon) henüz verilmedi — BILINMEYENLER'e yazıldı. Metinlerin yapısı
 * hazır; kimlik alanları işletmeden gelince bu bileşen kaldırılıp bilgiler
 * yerine konur. Uydurma bilgi yazılmadı.
 */
export function LegalNotice() {
  return (
    <p
      role="note"
      className="mt-6 rounded-card border border-warning/40 bg-warning/10 px-4 py-3 text-sm text-neutral-900"
    >
      <strong className="font-semibold">Yayın öncesi tamamlanacak:</strong> işletmenin ticari
      unvanı, merkez adresi, vergi dairesi ve numarası, MERSİS numarası ile KEP adresi bu metne
      eklenecektir. Bilgiler işletmeden alınmadan yayına çıkılmaz.
    </p>
  );
}
