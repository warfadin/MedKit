# MedKit+ Web

Bu uygulama SwiftUI projesiyle aynı depoda ayrı bir web dizini olarak incelenebilir. Sites dağıtımı bu dizindeki kaynakları kullanır. Klinik kılavuz ve hastane menüsü içerikleri [medkit-data](https://github.com/warfadin/medkit-data) üzerinden gelir.

## Yerel çalışma

Node.js 22 veya sonrası ile bu dizinde `npm run build`, `npm test` ve `npm run dev` çalıştırın. İlk derleme sabit bir medkit-data revizyonunu indirir. İsteğe bağlı `MEDKIT_DATA_CHECKOUT` değişkeni aynı revizyonun bulunduğu ayrı Git çalışma kopyasını kullanır. `MEDKIT_UNIVERSITY_HTML` değişkeni, resmî yemek sayfasından alınmış yerel HTML ile ilk dağıtımda Personel veya Çamlık arşivini hazırlamak için kullanılabilir. Derleme çıktısında türetilmiş çevrimdışı veri oluşur.

Tarayıcı, açılan modüle ait kayıtları hemen gösterir. Her veri kaynağı için otomatik istekler 24 saat arayla yapılır. Manuel yenileme bu süreyi beklemez. Son başarılı veri hata durumunda korunur. Service Worker, ilk başarılı çevrimiçi açılışta arayüzü ve sürüm arşivini saklar. Gizli gezinmede ya da tarayıcı depolamayı temizlediğinde çevrimdışı veri kullanılabilirliği değişebilir.

## Kapsam

Hesaplayıcı mevcut dört ajanı ve karışım seçeneklerini, manuel son hacmi ve iki yönlü birim dönüşümünü kapsar. İlk değerler kullanıcı tarafından girilir. iOS doz-etki yorumları ve tedavi önerileri web arayüzüne dahil edilmedi. Çamlık ve Personel ayrı gösterilir. Kaynakta Çamlık bulunamadığında ilgili sekme bu durumu bildirir. Tarihi geçmiş hastane menüsü arşiv olarak işaretlenir.
