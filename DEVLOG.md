# MedKit+ Geliştirme Günlüğü

## 2026-11-12 — Kılavuz konusu kimlik doğrulaması

- Kılavuz konusu açılırken ve önbellek yenilenirken konu kimliğini dizinle karşılaştırdık. Uzak AKI ve KBH dosyalarının mevcut kimliklerini kabul ettik. Eşleşmeyen uzak dosyada geçerli önbelleğe veya uygulama içindeki konuya dönülüyor.
- Swift regresyon testleri Linux'ta `FoundationNetworking` kullanılarak ve `OSLog` satırları geçici kopyadan çıkarılarak geçti. iOS derlemesi ve simülatör kontrolü bekliyor.
- [PR #2](https://github.com/warfadin/MedKit/pull/2)
- Sonraki adım, Xcode’da AKI ve KBH konularını bir kez çevrimiçi açıp ağ kapalıyken tekrar açarak doğrulamak.

macOS'ta servis regresyon testini depo kökünden çalıştırmak için:

```sh
test_dir=$(mktemp -d)
xcrun swiftc -swift-version 5 -parse-as-library \
  MedKitPlus/Features/GuideUpdates/GuideUpdatesModels.swift \
  MedKitPlus/Features/GuideUpdates/GuideUpdatesService.swift \
  scripts/test-guide-topic-identity.swift \
  -o "$test_dir/test-guide-topic-identity" && "$test_dir/test-guide-topic-identity"
```
