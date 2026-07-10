#!/usr/bin/env python3
"""Fill every remaining untranslated string for all 8 remaining languages."""

import json
from pathlib import Path

LANGS = ["es", "fr", "de", "pt", "ja", "ko", "zh-Hans", "zh-Hant"]

# Each entry maps English key → {lang: translation}
T = {
    # ── Brand / Proper nouns ──
    "A native macOS uninstaller by Codenta.": {
        "es":"Un desinstalador nativo macOS de Codenta.",
        "fr":"Un désinstallateur natif macOS par Codenta.",
        "de":"Ein nativer macOS-Deinstallierer von Codenta.",
        "pt":"Um desinstalador nativo macOS da Codenta.",
        "ja":"CodentaによるmacOSネイティブアンインストーラー。",
        "ko":"Codenta의 macOS 네이티브 언인스톨러.",
        "zh-Hans":"Codenta 出品的原生 macOS 卸载工具。",
        "zh-Hant":"Codenta 出品的原生 macOS 解除安裝工具。",
    },
    "App": {
        "es":"App","fr":"App","de":"App","pt":"App",
        "ja":"アプリ","ko":"앱","zh-Hans":"应用","zh-Hant":"應用程式",
    },
    "Apps": {
        "es":"Apps","fr":"Apps","de":"Apps","pt":"Apps",
        "ja":"アプリ","ko":"앱","zh-Hans":"应用","zh-Hant":"應用程式",
    },
    "Applications": {
        "es":"Aplicaciones","fr":"Applications","de":"Anwendungen","pt":"Aplicativos",
        "ja":"アプリ","ko":"앱","zh-Hans":"应用","zh-Hant":"應用程式",
    },
    "Beta": {
        "es":"Beta","fr":"Bêta","de":"Beta","pt":"Beta",
        "ja":"ベータ","ko":"베타","zh-Hans":"Beta","zh-Hant":"Beta",
    },
    "Cask": {
        "es":"Cask","fr":"Cask","de":"Cask","pt":"Cask",
        "ja":"Cask","ko":"Cask","zh-Hans":"Cask","zh-Hant":"Cask",
    },
    "codenta.us": {
        "es":"codenta.us","fr":"codenta.us","de":"codenta.us","pt":"codenta.us",
        "ja":"codenta.us","ko":"codenta.us","zh-Hans":"codenta.us","zh-Hant":"codenta.us",
    },
    "Formula": {
        "es":"Fórmula","fr":"Formule","de":"Formel","pt":"Fórmula",
        "ja":"Formula","ko":"Formula","zh-Hans":"Formula","zh-Hant":"Formula",
    },
    "GitHub": {
        "es":"GitHub","fr":"GitHub","de":"GitHub","pt":"GitHub",
        "ja":"GitHub","ko":"GitHub","zh-Hans":"GitHub","zh-Hant":"GitHub",
    },
    "Homebrew": {
        "es":"Homebrew","fr":"Homebrew","de":"Homebrew","pt":"Homebrew",
        "ja":"Homebrew","ko":"Homebrew","zh-Hans":"Homebrew","zh-Hant":"Homebrew",
    },
    "Layout": {
        "es":"Diseño","fr":"Disposition","de":"Layout","pt":"Layout",
        "ja":"レイアウト","ko":"레이아웃","zh-Hans":"布局","zh-Hant":"佈局",
    },
    "OK": {
        "es":"Aceptar","fr":"OK","de":"OK","pt":"OK",
        "ja":"OK","ko":"확인","zh-Hans":"确定","zh-Hant":"確定",
    },
    "uninstally": {
        "es":"uninstally","fr":"uninstally","de":"uninstally","pt":"uninstally",
        "ja":"uninstally","ko":"uninstally","zh-Hans":"uninstally","zh-Hant":"uninstally",
    },
    "Volume": {
        "es":"Volumen","fr":"Volume","de":"Volume","pt":"Volume",
        "ja":"ボリューム","ko":"볼륨","zh-Hans":"卷","zh-Hant":"卷",
    },

    # ── Common labels ──
    "Application": {
        "es":"Aplicación","fr":"Application","de":"Anwendung","pt":"Aplicativo",
        "ja":"アプリケーション","ko":"응용 프로그램","zh-Hans":"应用程序","zh-Hant":"應用程式",
    },
    "Name": {
        "es":"Nombre","fr":"Nom","de":"Name","pt":"Nome",
        "ja":"名前","ko":"이름","zh-Hans":"名称","zh-Hant":"名稱",
    },
    "Version": {
        "es":"Versión","fr":"Version","de":"Version","pt":"Versão",
        "ja":"バージョン","ko":"버전","zh-Hans":"版本","zh-Hant":"版本",
    },
    "Date": {
        "es":"Fecha","fr":"Date","de":"Datum","pt":"Data",
        "ja":"日付","ko":"날짜","zh-Hans":"日期","zh-Hant":"日期",
    },
    "Filter": {
        "es":"Filtro","fr":"Filtre","de":"Filter","pt":"Filtro",
        "ja":"フィルター","ko":"필터","zh-Hans":"过滤","zh-Hant":"過濾",
    },
    "Collections": {
        "es":"Colecciones","fr":"Collections","de":"Sammlungen","pt":"Coleções",
        "ja":"コレクション","ko":"컬렉션","zh-Hans":"收藏","zh-Hant":"收藏",
    },
    "Name": {
        "es":"Nombre","fr":"Nom","de":"Name","pt":"Nome",
        "ja":"名前","ko":"이름","zh-Hans":"名称","zh-Hant":"名稱",
    },
    "Version": {
        "es":"Versión","fr":"Version","de":"Version","pt":"Versão",
        "ja":"バージョン","ko":"버전","zh-Hans":"版本","zh-Hant":"版本",
    },
    "Status": {
        "es":"Estado","fr":"Statut","de":"Status","pt":"Status",
        "ja":"ステータス","ko":"상태","zh-Hans":"状态","zh-Hant":"狀態",
    },
    "Updates": {
        "es":"Actualizaciones","fr":"Mises à jour","de":"Updates","pt":"Atualizações",
        "ja":"アップデート","ko":"업데이트","zh-Hans":"更新","zh-Hant":"更新",
    },
    "Stable": {
        "es":"Estable","fr":"Stable","de":"Stabil","pt":"Estável",
        "ja":"安定版","ko":"안정판","zh-Hans":"稳定版","zh-Hant":"穩定版",
    },
    "Nightly": {
        "es":"Nocturno","fr":"Nocturne","de":"Nightly","pt":"Noturno",
        "ja":"ナイトリー","ko":"나이틀리","zh-Hans":"每日构建","zh-Hant":"每日構建",
    },

    # ── Settings / Update ──
    "Clear Ignored Version": {
        "es":"Limpiar versión ignorada","fr":"Effacer version ignorée","de":"Ignorierte Version löschen",
        "pt":"Limpar versão ignorada","ja":"無視したバージョンをクリア","ko":"무시된 버전 지우기",
        "zh-Hans":"清除忽略的版本","zh-Hant":"清除忽略的版本",
    },
    "Reset Update Preferences": {
        "es":"Restablecer preferencias de actualización","fr":"Réinitialiser préf. mises à jour",
        "de":"Update-Einstellungen zurücksetzen","pt":"Redefinir preferências de atualização",
        "ja":"更新設定をリセット","ko":"업데이트 설정 초기화",
        "zh-Hans":"重置更新偏好","zh-Hant":"重設更新偏好",
    },
    "Verified update source": {
        "es":"Fuente de actualización verificada","fr":"Source de mise à jour vérifiée",
        "de":"Verifizierte Update-Quelle","pt":"Fonte de atualização verificada",
        "ja":"検証済み更新ソース","ko":"검증된 업데이트 출처",
        "zh-Hans":"已验证的更新来源","zh-Hant":"已驗證的更新來源",
    },
    "Preferences reset. Relaunch to see all changes.": {
        "es":"Preferencias restablecidas. Reinicia para ver los cambios.",
        "fr":"Préférences réinitialisées. Relancez pour voir les changements.",
        "de":"Einstellungen zurückgesetzt. Neu starten für Änderungen.",
        "pt":"Preferências redefinidas. Reinicie para ver as alterações.",
        "ja":"設定がリセットされました。再起動して変更を確認してください。",
        "ko":"설정이 초기화되었습니다. 변경 사항을 보려면 다시 시작하세요.",
        "zh-Hans":"偏好设置已重置。重新启动以查看更改。",
        "zh-Hant":"偏好設定已重設。重新啟動以查看變更。",
    },
    "Open Settings": {
        "es":"Abrir Ajustes","fr":"Ouvrir Préférences","de":"Einstellungen öffnen",
        "pt":"Abrir Definições","ja":"設定を開く","ko":"설정 열기",
        "zh-Hans":"打开设置","zh-Hant":"開啟設定",
    },

    # ── Removal categories ──
    "Application Support": {
        "es":"Soporte de aplicación","fr":"Support d'application","de":"Anwendungsunterstützung",
        "pt":"Suporte de aplicativo","ja":"アプリケーションサポート","ko":"응용 프로그램 지원",
        "zh-Hans":"应用程序支持","zh-Hant":"應用程式支援",
    },
    "Caches": {
        "es":"Cachés","fr":"Caches","de":"Caches","pt":"Caches",
        "ja":"キャッシュ","ko":"캐시","zh-Hans":"缓存","zh-Hant":"快取",
    },
    "Cookies": {
        "es":"Cookies","fr":"Cookies","de":"Cookies","pt":"Cookies",
        "ja":"Cookie","ko":"쿠키","zh-Hans":"Cookie","zh-Hant":"Cookie",
    },
    "Extensions": {
        "es":"Extensiones","fr":"Extensions","de":"Erweiterungen","pt":"Extensões",
        "ja":"拡張機能","ko":"확장 기능","zh-Hans":"扩展","zh-Hant":"擴充功能",
    },
    "Group Containers": {
        "es":"Contenedores de grupo","fr":"Conteneurs de groupe","de":"Gruppen-Container",
        "pt":"Contêineres de grupo","ja":"グループコンテナ","ko":"그룹 컨테이너",
        "zh-Hans":"组容器","zh-Hant":"群組容器",
    },
    "HTTP Storage": {
        "es":"Almacenamiento HTTP","fr":"Stockage HTTP","de":"HTTP-Speicher",
        "pt":"Armazenamento HTTP","ja":"HTTPストレージ","ko":"HTTP 저장소",
        "zh-Hans":"HTTP 存储","zh-Hant":"HTTP 儲存",
    },
    "Other Support Files": {
        "es":"Otros archivos de soporte","fr":"Autres fichiers de support","de":"Weitere Support-Dateien",
        "pt":"Outros arquivos de suporte","ja":"その他のサポートファイル","ko":"기타 지원 파일",
        "zh-Hans":"其他支持文件","zh-Hant":"其他支援檔案",
    },
    "Privileged Helpers": {
        "es":"Asistentes privilegiados","fr":"Assistants privilégiés","de":"Privilegierte Helfer",
        "pt":"Assistentes privilegiados","ja":"特権ヘルパー","ko":"권한 있는 도우미",
        "zh-Hans":"特权助手","zh-Hant":"特權輔助程式",
    },
    "QuickLook Plugins": {
        "es":"Plugins QuickLook","fr":"Plugins QuickLook","de":"QuickLook-Plugins",
        "pt":"Plugins QuickLook","ja":"QuickLookプラグイン","ko":"QuickLook 플러그인",
        "zh-Hans":"QuickLook 插件","zh-Hant":"QuickLook 插件",
    },
    "Spotlight Metadata": {
        "es":"Metadatos Spotlight","fr":"Métadonnées Spotlight","de":"Spotlight-Metadaten",
        "pt":"Metadados Spotlight","ja":"Spotlightメタデータ","ko":"Spotlight 메타데이터",
        "zh-Hans":"Spotlight 元数据","zh-Hant":"Spotlight 中繼資料",
    },
    "Support Files": {
        "es":"Archivos de soporte","fr":"Fichiers de support","de":"Support-Dateien",
        "pt":"Arquivos de suporte","ja":"サポートファイル","ko":"지원 파일",
        "zh-Hans":"支持文件","zh-Hant":"支援檔案",
    },
    "WebKit Data": {
        "es":"Datos WebKit","fr":"Données WebKit","de":"WebKit-Daten",
        "pt":"Dados WebKit","ja":"WebKitデータ","ko":"WebKit 데이터",
        "zh-Hans":"WebKit 数据","zh-Hant":"WebKit 資料",
    },
    "Widgets": {
        "es":"Widgets","fr":"Widgets","de":"Widgets","pt":"Widgets",
        "ja":"ウィジェット","ko":"위젯","zh-Hans":"小组件","zh-Hant":"小工具",
    },
    "Services": {
        "es":"Servicios","fr":"Services","de":"Dienste","pt":"Serviços",
        "ja":"サービス","ko":"서비스","zh-Hans":"服务","zh-Hant":"服務",
    },

    # ── History / Records ──
    "Clear all uninstall history?": {
        "es":"¿Borrar todo el historial de desinstalación?","fr":"Effacer tout l'historique de désinstallation?",
        "de":"Gesamten Deinstallationsverlauf löschen?","pt":"Limpar todo o histórico de desinstalação?",
        "ja":"すべてのアンインストール履歴を消去しますか？","ko":"모든 제거 기록을 지우시겠습니까？",
        "zh-Hans":"清除所有卸载历史？","zh-Hant":"清除所有解除安裝歷史？",
    },
    "Clear all history": {
        "es":"Borrar todo el historial","fr":"Effacer tout l'historique",
        "de":"Gesamten Verlauf löschen","pt":"Limpar todo o histórico",
        "ja":"すべての履歴を消去","ko":"모든 기록 지우기",
        "zh-Hans":"清除所有历史","zh-Hant":"清除所有歷史",
    },
    "No Uninstall History": {
        "es":"Sin historial de desinstalación","fr":"Aucun historique de désinstallation",
        "de":"Kein Deinstallationsverlauf","pt":"Nenhum histórico de desinstalação",
        "ja":"アンインストール履歴なし","ko":"제거 기록 없음",
        "zh-Hans":"无卸载历史","zh-Hant":"無解除安裝歷史",
    },
    "Apps Uninstalled": {
        "es":"Apps desinstaladas","fr":"Apps désinstallées","de":"Apps deinstalliert",
        "pt":"Apps desinstalados","ja":"アンインストール済みアプリ","ko":"제거된 앱",
        "zh-Hans":"已卸载应用","zh-Hant":"已解除安裝應用程式",
    },
    "Last Uninstall": {
        "es":"Última desinstalación","fr":"Dernière désinstallation","de":"Letzte Deinstallation",
        "pt":"Última desinstalação","ja":"最後のアンインストール","ko":"마지막 제거",
        "zh-Hans":"上次卸载","zh-Hant":"上次解除安裝",
    },
    "Average Recovered": {
        "es":"Promedio recuperado","fr":"Moyenne récupérée","de":"Durchschnittlich zurückgewonnen",
        "pt":"Média recuperada","ja":"平均回復量","ko":"평균 복구량",
        "zh-Hans":"平均回收","zh-Hant":"平均回收",
    },
    "Delete Permanently": {
        "es":"Eliminar permanentemente","fr":"Supprimer définitivement","de":"Endgültig löschen",
        "pt":"Excluir permanentemente","ja":"完全に削除","ko":"영구 삭제",
        "zh-Hans":"永久删除","zh-Hant":"永久刪除",
    },
    "Permanent Delete": {
        "es":"Eliminación permanente","fr":"Suppression définitive","de":"Endgültig gelöscht",
        "pt":"Exclusão permanente","ja":"完全削除","ko":"영구 삭제",
        "zh-Hans":"永久删除","zh-Hant":"永久刪除",
    },
    "Original Location": {
        "es":"Ubicación original","fr":"Emplacement d'origine","de":"Ursprünglicher Ort",
        "pt":"Localização original","ja":"元の場所","ko":"원래 위치",
        "zh-Hans":"原始位置","zh-Hant":"原始位置",
    },
    "View Details": {
        "es":"Ver detalles","fr":"Voir détails","de":"Details anzeigen",
        "pt":"Ver detalhes","ja":"詳細を表示","ko":"세부 정보 보기",
        "zh-Hans":"查看详情","zh-Hant":"檢視詳細資料",
    },
    "No longer in the Trash": {
        "es":"Ya no está en la Papelera","fr":"Plus dans la Corbeille",
        "de":"Nicht mehr im Papierkorb","pt":"Não está mais na Lixeira",
        "ja":"ゴミ箱にもうありません","ko":"더 이상 휴지통에 없음",
        "zh-Hans":"不再在废纸篓中","zh-Hant":"不再在垃圾桶中",
    },
    "Reveal Original Location": {
        "es":"Mostrar ubicación original","fr":"Afficher emplacement d'origine",
        "de":"Ursprünglichen Ort zeigen","pt":"Mostrar localização original",
        "ja":"元の場所を表示","ko":"원래 위치 보기",
        "zh-Hans":"显示原始位置","zh-Hant":"顯示原始位置",
    },
    "Untitled Collection": {
        "es":"Colección sin título","fr":"Collection sans titre","de":"Unbenannte Sammlung",
        "pt":"Coleção sem título","ja":"無題のコレクション","ko":"제목 없는 컬렉션",
        "zh-Hans":"未命名收藏","zh-Hant":"未命名收藏",
    },

    # ── Search / Browser ──
    "Search apps and leftovers": {
        "es":"Buscar apps y residuos","fr":"Rechercher apps et résidus",
        "de":"Apps und Reste suchen","pt":"Pesquisar apps e resíduos",
        "ja":"アプリと残存を検索","ko":"앱 및 잔여물 검색",
        "zh-Hans":"搜索应用和残留","zh-Hant":"搜尋應用程式和殘留",
    },
    "Search leftovers": {
        "es":"Buscar residuos","fr":"Rechercher résidus","de":"Reste suchen",
        "pt":"Pesquisar resíduos","ja":"残存を検索","ko":"잔여물 검색",
        "zh-Hans":"搜索残留","zh-Hant":"搜尋殘留",
    },
    "Sections": {
        "es":"Secciones","fr":"Sections","de":"Bereiche","pt":"Seções",
        "ja":"セクション","ko":"섹션","zh-Hans":"部分","zh-Hant":"區段",
    },
    "Empty Collection": {
        "es":"Colección vacía","fr":"Collection vide","de":"Leere Sammlung",
        "pt":"Coleção vazia","ja":"空のコレクション","ko":"빈 컬렉션",
        "zh-Hans":"空收藏","zh-Hant":"空收藏",
    },
    "No Applications": {
        "es":"Sin aplicaciones","fr":"Aucune application","de":"Keine Anwendungen",
        "pt":"Nenhum aplicativo","ja":"アプリケーションがありません","ko":"응용 프로그램 없음",
        "zh-Hans":"无应用程序","zh-Hant":"無應用程式",
    },
    "Nothing matches this filter.": {
        "es":"Nada coincide con este filtro.","fr":"Aucun résultat pour ce filtre.",
        "de":"Keine Ergebnisse für diesen Filter.","pt":"Nada corresponde a este filtro.",
        "ja":"このフィルターに一致するものはありません。","ko":"이 필터와 일치하는 항목이 없습니다.",
        "zh-Hans":"没有匹配此过滤条件的内容。","zh-Hant":"沒有符合此過濾條件的內容。",
    },
    "No matching applications": {
        "es":"Sin aplicaciones coincidentes","fr":"Aucune application correspondante",
        "de":"Keine passenden Anwendungen","pt":"Nenhum aplicativo correspondente",
        "ja":"一致するアプリケーションがありません","ko":"일치하는 응용 프로그램 없음",
        "zh-Hans":"没有匹配的应用程序","zh-Hant":"沒有符合的應用程式",
    },
    "No matching files": {
        "es":"Sin archivos coincidentes","fr":"Aucun fichier correspondant",
        "de":"Keine passenden Dateien","pt":"Nenhum arquivo correspondente",
        "ja":"一致するファイルがありません","ko":"일치하는 파일 없음",
        "zh-Hans":"没有匹配的文件","zh-Hant":"沒有符合的檔案",
    },
    "Change the sort order": {
        "es":"Cambiar orden de clasificación","fr":"Changer l'ordre de tri",
        "de":"Sortierreihenfolge ändern","pt":"Alterar ordem de classificação",
        "ja":"並べ替え順序を変更","ko":"정렬 순서 변경",
        "zh-Hans":"更改排序顺序","zh-Hant":"更改排序順序",
    },
    "Select multiple applications to uninstall together": {
        "es":"Seleccionar varias aplicaciones para desinstalar juntas",
        "fr":"Sélectionner plusieurs applications à désinstaller ensemble",
        "de":"Mehrere Anwendungen zum gemeinsamen Deinstallieren auswählen",
        "pt":"Selecionar vários aplicativos para desinstalar juntos",
        "ja":"複数のアプリケーションをまとめてアンインストール",
        "ko":"여러 응용 프로그램을 함께 제거하도록 선택",
        "zh-Hans":"选择多个应用程序一起卸载",
        "zh-Hant":"選擇多個應用程式一起解除安裝",
    },
    "Refresh the application list": {
        "es":"Actualizar la lista de aplicaciones","fr":"Actualiser la liste des applications",
        "de":"Anwendungsliste aktualisieren","pt":"Atualizar a lista de aplicativos",
        "ja":"アプリケーション一覧を更新","ko":"응용 프로그램 목록 새로고침",
        "zh-Hans":"刷新应用程序列表","zh-Hant":"重新整理應用程式列表",
    },

    # ── Storage Insights ──
    "Total Installed Size": {
        "es":"Tamaño total instalado","fr":"Taille totale installée","de":"Gesamtgröße installiert",
        "pt":"Tamanho total instalado","ja":"インストール済み合計サイズ","ko":"설치된 총 크기",
        "zh-Hans":"已安装总大小","zh-Hant":"已安裝總大小",
    },
    "Largest Installed App": {
        "es":"App instalada más grande","fr":"Plus grande app installée","de":"Größte installierte App",
        "pt":"Maior app instalado","ja":"最大のインストール済みアプリ","ko":"가장 큰 설치된 앱",
        "zh-Hans":"最大已安装应用","zh-Hant":"最大已安裝應用程式",
    },
    "Total Space Recovered": {
        "es":"Espacio total recuperado","fr":"Espace total récupéré","de":"Gesamter zurückgewonnener Speicher",
        "pt":"Espaço total recuperado","ja":"合計回復容量","ko":"총 복구된 공간",
        "zh-Hans":"总回收空间","zh-Hant":"總回收空間",
    },
    "Apps Removed": {
        "es":"Apps eliminadas","fr":"Apps supprimées","de":"Apps entfernt",
        "pt":"Apps removidos","ja":"削除されたアプリ","ko":"제거된 앱",
        "zh-Hans":"已删除应用","zh-Hant":"已刪除應用程式",
    },
    "Average Space Recovered": {
        "es":"Espacio promedio recuperado","fr":"Espace moyen récupéré","de":"Durchschnittlich zurückgewonnener Speicher",
        "pt":"Espaço médio recuperado","ja":"平均回復容量","ko":"평균 복구된 공간",
        "zh-Hans":"平均回收空间","zh-Hant":"平均回收空間",
    },
    "Largest Applications": {
        "es":"Aplicaciones más grandes","fr":"Plus grandes applications","de":"Größte Anwendungen",
        "pt":"Maiores aplicativos","ja":"最大のアプリ","ko":"가장 큰 응용 프로그램",
        "zh-Hans":"最大应用程序","zh-Hant":"最大應用程式",
    },
    "Largest Leftover Files": {
        "es":"Archivos residuales más grandes","fr":"Plus grands fichiers résiduels","de":"Größte Restdateien",
        "pt":"Maiores arquivos residuais","ja":"最大の残存ファイル","ko":"가장 큰 잔여 파일",
        "zh-Hans":"最大残留文件","zh-Hant":"最大殘留檔案",
    },
    "Unused Applications": {
        "es":"Aplicaciones sin usar","fr":"Applications inutilisées","de":"Ungenutzte Anwendungen",
        "pt":"Aplicativos não utilizados","ja":"未使用のアプリ","ko":"사용되지 않는 앱",
        "zh-Hans":"未使用的应用","zh-Hant":"未使用的應用程式",
    },
    "Total Recoverable Storage": {
        "es":"Almacenamiento total recuperable","fr":"Stockage total récupérable","de":"Wiederherstellbarer Gesamtspeicher",
        "pt":"Armazenamento total recuperável","ja":"回復可能な合計ストレージ","ko":"총 복구 가능한 저장소",
        "zh-Hans":"可恢复的总存储空间","zh-Hant":"可恢復的總儲存空間",
    },

    # ── Charts (residual references) ──
    "Storage by Category": {
        "es":"Almacenamiento por categoría","fr":"Stockage par catégorie","de":"Speicher nach Kategorie",
        "pt":"Armazenamento por categoria","ja":"カテゴリ別ストレージ","ko":"카테고리별 저장소",
        "zh-Hans":"按类别存储","zh-Hant":"按類別儲存",
    },
    "Application Count by Category": {
        "es":"Conteo de apps por categoría","fr":"Nombre d'apps par catégorie","de":"Anzahl Apps nach Kategorie",
        "pt":"Contagem de apps por categoria","ja":"カテゴリ別アプリ数","ko":"카테고리별 앱 수",
        "zh-Hans":"按类别应用数量","zh-Hant":"按類別應用程式數量",
    },
    "Recovered Storage Over Time": {
        "es":"Almacenamiento recuperado en el tiempo","fr":"Stockage récupéré dans le temps","de":"Zurückgewonnener Speicher im Zeitverlauf",
        "pt":"Armazenamento recuperado ao longo do tempo","ja":"時間経過での回復ストレージ","ko":"시간별 복구된 저장소",
        "zh-Hans":"随时间恢复的存储空间","zh-Hant":"隨時間恢復的儲存空間",
    },
    "Installed Apps by Developer": {
        "es":"Apps instaladas por desarrollador","fr":"Apps installées par développeur","de":"Installierte Apps nach Entwickler",
        "pt":"Apps instalados por desenvolvedor","ja":"開発者別インストール済みアプリ","ko":"개발자별 설치된 앱",
        "zh-Hans":"按开发者安装的应用","zh-Hant":"按開發者安裝的應用程式",
    },
    "Not enough history yet": {
        "es":"Aún no hay suficiente historial","fr":"Pas encore assez d'historique","de":"Noch nicht genug Verlauf",
        "pt":"Ainda não há histórico suficiente","ja":"まだ十分な履歴がありません","ko":"아직 충분한 기록이 없습니다",
        "zh-Hans":"历史记录不足","zh-Hant":"歷史記錄不足",
    },
    "No data yet": {
        "es":"Sin datos aún","fr":"Pas encore de données","de":"Noch keine Daten",
        "pt":"Sem dados ainda","ja":"まだデータがありません","ko":"아직 데이터 없음",
        "zh-Hans":"暂无数据","zh-Hant":"暫無資料",
    },

    # ── Simulation / Uninstall Details ──
    "Uninstall Simulation": {
        "es":"Simulación de desinstalación","fr":"Simulation de désinstallation","de":"Deinstallations-Simulation",
        "pt":"Simulação de desinstalação","ja":"アンインストールシミュレーション","ko":"제거 시뮬레이션",
        "zh-Hans":"卸载模拟","zh-Hant":"解除安裝模擬",
    },
    "Simulation Report": {
        "es":"Informe de simulación","fr":"Rapport de simulation","de":"Simulationsbericht",
        "pt":"Relatório de simulação","ja":"シミュレーションレポート","ko":"시뮬레이션 보고서",
        "zh-Hans":"模拟报告","zh-Hant":"模擬報告",
    },
    "Total Files": {
        "es":"Archivos totales","fr":"Fichiers totaux","de":"Gesamtdateien",
        "pt":"Total de arquivos","ja":"合計ファイル数","ko":"총 파일",
        "zh-Hans":"文件总数","zh-Hant":"檔案總數",
    },
    "Recoverable": {
        "es":"Recuperable","fr":"Récupérable","de":"Wiederherstellbar",
        "pt":"Recuperável","ja":"回復可能","ko":"복구 가능",
        "zh-Hans":"可恢复","zh-Hant":"可恢復",
    },
    "Background Components": {
        "es":"Componentes en segundo plano","fr":"Composants d'arrière-plan","de":"Hintergrundkomponenten",
        "pt":"Componentes em segundo plano","ja":"バックグラウンドコンポーネント","ko":"백그라운드 구성 요소",
        "zh-Hans":"后台组件","zh-Hant":"背景組件",
    },
    "Estimated Time": {
        "es":"Tiempo estimado","fr":"Temps estimé","de":"Geschätzte Zeit",
        "pt":"Tempo estimado","ja":"推定時間","ko":"예상 시간",
        "zh-Hans":"预计时间","zh-Hant":"預計時間",
    },
    "Review Individually": {
        "es":"Revisar individualmente","fr":"Examiner individuellement","de":"Einzeln überprüfen",
        "pt":"Revisar individualmente","ja":"個別に確認","ko":"개별 검토",
        "zh-Hans":"逐一检查","zh-Hant":"逐一檢查",
    },
    "Cache Folders Removed": {
        "es":"Carpetas de caché eliminadas","fr":"Dossiers de cache supprimés","de":"Cache-Ordner entfernt",
        "pt":"Pastas de cache removidas","ja":"キャッシュフォルダ削除済み","ko":"캐시 폴더 제거됨",
        "zh-Hans":"已删除缓存文件夹","zh-Hant":"已刪除快取檔案夾",
    },
    "Preference Files Removed": {
        "es":"Archivos de preferencias eliminados","fr":"Fichiers de préférences supprimés","de":"Einstellungsdateien entfernt",
        "pt":"Arquivos de preferências removidos","ja":"設定ファイル削除済み","ko":"환경설정 파일 제거됨",
        "zh-Hans":"已删除偏好设置文件","zh-Hant":"已刪除偏好設定檔案",
    },
    "Saved State Removed": {
        "es":"Estado guardado eliminado","fr":"État enregistré supprimé","de":"Gespeicherter Zustand entfernt",
        "pt":"Estado salvo removido","ja":"保存状態削除済み","ko":"저장된 상태 제거됨",
        "zh-Hans":"已删除保存状态","zh-Hant":"已刪除儲存狀態",
    },
    "Login Items Removed": {
        "es":"Elementos de inicio eliminados","fr":"Ouverture de session retirée","de":"Anmeldeobjekte entfernt",
        "pt":"Itens de login removidos","ja":"ログイン項目削除済み","ko":"로그인 항목 제거됨",
        "zh-Hans":"已删除登录项","zh-Hant":"已刪除登入項目",
    },
    "Launch Agents Removed": {
        "es":"Agentes de inicio eliminados","fr":"Agents de lancement retirés","de":"Start-Agenten entfernt",
        "pt":"Agentes de inicialização removidos","ja":"起動エージェント削除済み","ko":"시작 에이전트 제거됨",
        "zh-Hans":"已删除启动代理","zh-Hant":"已刪除啟動代理",
    },
    "Finder Extensions Removed": {
        "es":"Extensiones de Finder eliminadas","fr":"Extensions Finder retirées","de":"Finder-Erweiterungen entfernt",
        "pt":"Extensões do Finder removidas","ja":"Finder拡張削除済み","ko":"Finder 확장 제거됨",
        "zh-Hans":"已删除 Finder 扩展","zh-Hant":"已刪除 Finder 擴充功能",
    },
    "Background Services Removed": {
        "es":"Servicios en segundo plano eliminados","fr":"Services d'arrière-plan retirés","de":"Hintergrunddienste entfernt",
        "pt":"Serviços em segundo plano removidos","ja":"バックグラウンドサービス削除済み","ko":"백그라운드 서비스 제거됨",
        "zh-Hans":"已删除后台服务","zh-Hant":"已刪除背景服務",
    },

    # ── Homebrew ──
    "Also remove configuration & leftover files (--zap)": {
        "es":"Eliminar también configuración y archivos residuales (--zap)",
        "fr":"Supprimer aussi la configuration et les fichiers résiduels (--zap)",
        "de":"Auch Konfiguration und Restdateien entfernen (--zap)",
        "pt":"Remover também configuração e arquivos residuais (--zap)",
        "ja":"設定と残存ファイルも削除 (--zap)","ko":"구성 및 잔여 파일도 제거 (--zap)",
        "zh-Hans":"同时删除配置和残留文件 (--zap)","zh-Hant":"同時刪除設定和殘留檔案 (--zap)",
    },
    "Reading Homebrew packages…": {
        "es":"Leyendo paquetes de Homebrew\u2026","fr":"Lecture des paquets Homebrew\u2026",
        "de":"Lese Homebrew-Pakete\u2026","pt":"Lendo pacotes do Homebrew\u2026",
        "ja":"Homebrewパッケージを読み込み中\u2026","ko":"Homebrew 패키지 읽는 중\u2026",
        "zh-Hans":"正在读取 Homebrew 软件包\u2026","zh-Hant":"正在讀取 Homebrew 軟體套件\u2026",
    },
    "Resolving dependencies…": {
        "es":"Resolviendo dependencias\u2026","fr":"Résolution des dépendances\u2026",
        "de":"Abhängigkeiten werden aufgelöst\u2026","pt":"Resolvendo dependências\u2026",
        "ja":"依存関係を解決中\u2026","ko":"의존성 확인 중\u2026",
        "zh-Hans":"正在解析依赖关系\u2026","zh-Hant":"正在解析相依關係\u2026",
    },
    "Required by (will break):": {
        "es":"Requerido por (se romperá):","fr":"Requis par (cassera):",
        "de":"Benötigt von (wird brechen):","pt":"Necessário para (irá quebrar):",
        "ja":"必要としているもの（壊れます）:","ko":"필요로 하는 것 (중단됨):",
        "zh-Hans":"被依赖（将损坏）：","zh-Hant":"被依賴（將損壞）：",
    },
    "Depends on:": {
        "es":"Depende de:","fr":"Dépend de :","de":"Abhängig von:","pt":"Depende de:",
        "ja":"依存:", "ko":"의존:","zh-Hans":"依赖于：","zh-Hant":"依賴於：",
    },
    "No dependency relationships detected.": {
        "es":"No se detectaron relaciones de dependencia.","fr":"Aucune relation de dépendance détectée.",
        "de":"Keine Abhängigkeitsbeziehungen erkannt.","pt":"Nenhuma relação de dependência detectada.",
        "ja":"依存関係は検出されませんでした。","ko":"의존 관계가 감지되지 않았습니다.",
        "zh-Hans":"未检测到依赖关系。","zh-Hant":"未偵測到相依關係。",
    },

    # ── Security ──
    "Broken alias": {
        "es":"Alias roto","fr":"Alias cassé","de":"Defekter Alias","pt":"Atalho quebrado",
        "ja":"壊れたエイリアス","ko":"손상된 별칭","zh-Hans":"损坏的别名","zh-Hant":"損壞的別名",
    },
    "The application bundle": {
        "es":"El paquete de la aplicación","fr":"Le bundle de l'application","de":"Das Anwendungsbundle",
        "pt":"O pacote do aplicativo","ja":"アプリケーションバンドル","ko":"응용 프로그램 번들",
        "zh-Hans":"应用程序包","zh-Hant":"應用程式套件",
    },

    # ── Notifications ──
    "Scan Leftovers": {
        "es":"Escanear residuos","fr":"Scanner les résidus","de":"Reste scannen",
        "pt":"Escanear resíduos","ja":"残存をスキャン","ko":"잔여물 스캔",
        "zh-Hans":"扫描残留","zh-Hant":"掃描殘留",
    },
    "Application Moved to Trash": {
        "es":"App movida a la Papelera","fr":"App placée dans la Corbeille","de":"App in Papierkorb verschoben",
        "pt":"App movido para a Lixeira","ja":"アプリをゴミ箱に移動","ko":"앱을 휴지통으로 이동",
        "zh-Hans":"应用已移至废纸篓","zh-Hant":"應用程式已移至垃圾桶",
    },
}

def main():
    path = Path(__file__).parent.parent / "Uninstally" / "Localizable.xcstrings"
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    strings = data.get("strings", {})
    fixed = 0

    for key, translations in T.items():
        if key not in strings:
            continue
        locs = strings[key].setdefault("localizations", {})

        for lang in LANGS:
            if lang in translations:
                locs[lang] = {
                    "stringUnit": {"state": "translated", "value": translations[lang]}
                }
                fixed += 1

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Fixed {fixed} translations across {len(T)} keys.")

if __name__ == "__main__":
    main()
