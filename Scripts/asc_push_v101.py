#!/usr/bin/env python3
"""Push PureScan v1.0.1 (build 2) + 10-Locale US Cross-Localization ASO & Submit via ASC REST API."""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Optional

KEY_ID = "BD4GFRDCQ9"
ISSUER_ID = "ccf96e7a-0987-4f4b-aa61-863fccd82c33"
KEY_PATH = "/Users/wang/.appstoreconnect/private_keys/AuthKey_BD4GFRDCQ9.p8"
APP_ID = "6837347918"
TARGET_VERSION = "1.0.1"
TARGET_BUILD = "2"

ROOT = Path(__file__).resolve().parent.parent
SHOT_ROOT = Path("/Users/wang/OPC/media/20261120-purescan/appstore")

URLS = {
    "marketing": "https://a3152557994-ship-it.github.io/purescan/",
    "support": "https://a3152557994-ship-it.github.io/purescan/support.html",
    "privacy": "https://a3152557994-ship-it.github.io/purescan/privacy.html",
}

EN_DESC = (
    "Tired of ingredient scanner apps that fail with 'Barcode Not Found' on local snacks, store brands, imported items, or pet food—or lock you out behind aggressive paywalls and logins?\n\n"
    "PureScan reads the actual ingredient label directly using 100% on-device Apple Vision OCR. Zero ads, zero accounts, zero cloud uploads—works instantaneously even in supermarket aisles with zero signal!\n\n"
    "KEY FEATURES\n"
    "• Instant Offline Label OCR (Not Limited by Barcodes): Scan food packages, local store brands, imported snacks, skincare INCI bottles, cat/dog kibble, or online shopping screenshots in 0.3 seconds.\n"
    "• 6 Personalized Health & Safety Radars: Tailor PureScan to YOU — Clean Additives, Low Sugar/Keto, Gout/High Purine (catches sneaky Yeast Extract & E635), Mom & Kids, Acne/Sensitive Skincare INCI, and Pet Food Safety (with automatic Grain-Splitting Trap detection!).\n"
    "• Custom Allergen Blacklist: Add your own red-flag triggers (Peanut, Gluten, Soy, Dairy) for instant red alerts.\n"
    "• Supermarket VS Showdown: Compare two yogurts, breads, or cat foods side-by-side to see the cleaner winner in 1 second.\n"
    "• Red & Green Cabinet + Shareable Inspection Receipts: Save Buy-Again favorites, blacklist junk forever, and export crisp lab-receipt cards.\n\n"
    "FAIR & TRANSPARENT PRO ACCESS\n"
    "• Free forever: 10 offline scans/day, zero ads, no login required.\n"
    "• PureScan Pro: Monthly ($1.99/mo), Annual ($9.99/yr with 3-day free trial + built-in Day-2 local reminder), or Lifetime Pay-Once ($14.99).\n\n"
    "Educational reference only based on public FDA/EFSA/GB 2760/INCI/AAFCO standards; not medical advice.\n"
    "Privacy Policy: https://a3152557994-ship-it.github.io/purescan/privacy.html\n"
    "Terms of Use (EULA): https://a3152557994-ship-it.github.io/purescan/terms.html"
)

ZH_HANS_DESC = (
    "逛超市买面包、酸奶、零食、护肤品或猫狗粮，想扫一眼配料表避雷，结果同类软件不是满屏摇一摇乱跳广告、就是条形码十样七样查不到，甚至查两次就逼充 ¥198 会员？\n\n"
    "「配料照妖镜」就是为你做的 0 广告、免登录、100% 离线配料表扫描仪：\n\n"
    "【为什么大家换用配料照妖镜？】\n"
    "1. 不靠残缺条形码，直接 0.3 秒离线识读配料表原文\n"
    "基于 Apple 原生设备端 Vision 文字识别引擎，山姆、进口货、烘焙短保、护肤品中英文 INCI、猫狗粮 100% 全扫得出！地下超市负二层没信号照样秒出结果，照片绝不上传云端。\n\n"
    "2. 永久 0 广告、0 开屏、0 摇一摇跳屏、无需注册登录\n"
    "打开直接对着配料表拍，也支持直接导入商品详情页截图一键扫雷。\n\n"
    "3. 6 大专属个人忌口雷达，按你的身体精准亮红灯\n"
    "- 科技与狠活雷达：紧盯新国标 GB 2760-2024 烘焙禁用脱氢乙酸钠、氢化植物油、亚硝酸钠、TBHQ、人工合成色素。\n"
    "- 控糖减脂雷达：揪出配料前三位加糖、果葡糖浆、麦芽糊精、植脂末与代糖。\n"
    "- 痛风 / 高尿酸雷达：专门拦截酵母抽提物、呈味核苷酸二钠 (E635)、海鲜浓缩粉与高果糖。\n"
    "- 孕期与宝妈雷达：规避人工色素、防腐剂、咖啡因、酒精与孕慎护肤 A 醇。\n"
    "- 敏感肌 / 致痘护肤雷达：识读中英文 INCI，揪出致痘酯 IPM/IPP、MIT 防腐、甲醛释放体与高浓度酒精。\n"
    "- 猫狗粮避毒雷达：拦住木糖醇/洋葱/BHA/诱食剂，自动识破“谷物分割法”陷阱！\n\n"
    "4. 超市「双品 VS 成分大决战」+ 我的红黑囤货柜\n"
    "左扫一包、右扫一包，1 秒同屏盖章谁更干净；支持安心回购与永久拉黑，一键生成质检避雷小票图！\n\n"
    "【透明良心权益】\n"
    "- 免费版每天可离线扫描 10 次，永久无广告、不强制登录。\n"
    "- Pro 会员提供月度（¥6/月）、年度（¥18/年，含 3 天免费试用且第 2 天主动推送到期提醒）、以及一次买断终身版（¥28）。\n\n"
    "免责声明：本应用依据公开标准做日常消费科普参考，不替代医生、营养师或兽医专业意见。\n"
    "隐私政策：https://a3152557994-ship-it.github.io/purescan/privacy.html\n"
    "使用条款：https://a3152557994-ship-it.github.io/purescan/terms.html"
)

ZH_HANT_DESC = (
    "逛超市買麵包、優格、零食、護膚品或貓狗糧，想掃一眼成分表避雷，卻遇到條碼十樣七樣查不到、滿螢幕彈窗廣告，或掃兩次就被迫高價訂閱？\n\n"
    "「配料照妖鏡」是專為你打造的 0 廣告、免登入、100% 本機離線食品添加劑與成分掃描儀：\n\n"
    "【核心亮點】\n"
    "1. 不靠殘缺條碼，直接 0.3 秒離線辨識成分表原文\n"
    "採用 Apple 原生裝置端 Vision OCR 引擎，港台超市零食、烘焙短保、進口食品、護膚品中英文 INCI、貓糧狗糧全都能掃！地下賣場無網路訊號照樣秒出結果，照片絕不上傳雲端。\n\n"
    "2. 永久 0 廣告、0 開屏跳轉、無須註冊登入\n"
    "打開即拍，也支援直接匯入相簿照片或網購商品詳情截圖一鍵分析。\n\n"
    "3. 6 大專屬個人忌口雷達，精準標紅避雷\n"
    "• 食品添加劑雷達：緊盯脫氫乙酸鈉、氫化植物油、亞硝酸鈉、TBHQ、人工合成色素。\n"
    "• 控糖減脂雷達：揪出前三位加糖、果葡糖漿、麥芽糊精、奶精與人工代糖。\n"
    "• 痛風 / 高尿酸雷達：攔截酵母抽提物、呈味核苷酸二鈉 (E635)、海鮮濃縮粉與高果糖。\n"
    "• 孕期與寶媽雷達：規避人工色素、防腐劑、咖啡因、酒精與孕慎 A 醇。\n"
    "• 敏感肌 / 致痘護膚雷達：解析中英文 INCI，揪出致痘酯 IPM/IPP、MIT 防腐與高濃度酒精。\n"
    "• 貓狗糧避毒雷達：攔住木糖醇、洋蔥、BHA 與誘食劑，自動識破「穀物分割法」陷阱！\n\n"
    "4. 超市「雙品 VS 成分大對決」+ 紅黑囤貨櫃\n"
    "兩款商品同螢幕 1 秒比出誰更乾淨；安心回購與永久拉黑一目了然，還能匯出質感檢驗小票圖。\n\n"
    "【透明良心方案】\n"
    "• 免費版每天可離線掃描 10 次，永久無廣告、不強制登入。\n"
    "• Pro 提供月度方案、年度方案（含 3 天免費試用與第 2 天到期提醒），以及最受歡迎的一次買斷終身版。\n\n"
    "免責聲明：本應用依據公開標準（FDA / EFSA / GB 2760 / INCI / AAFCO）提供日常消費科普參考，不替代醫師或獸醫師專業意見。\n"
    "隱私權政策：https://a3152557994-ship-it.github.io/purescan/privacy.html\n"
    "使用條款：https://a3152557994-ship-it.github.io/purescan/terms.html"
)

ES_MX_DESC = (
    "¿Cansado de apps de escaneo que dicen 'Código de barras no encontrado' en productos locales, importados, cosméticos o croquetas—o que te llenan de anuncios y registros obligatorios?\n\n"
    "PureScan lee directamente la lista de ingredientes en 0.3 segundos usando Apple Vision OCR 100% en tu iPhone. Cero anuncios, cero cuentas, cero envíos a la nube—funciona sin señal en cualquier supermercado.\n\n"
    "FUNCIONES PRINCIPALES\n"
    "• OCR Offline Instantáneo (Sin depender de códigos de barras): Escanea alimentos, marcas locales, cosméticos INCI, comida para perros y gatos o capturas de pantalla.\n"
    "• 6 Radares Personalizados: Aditivos y ultraprocesados, Bajo en Azúcar/Keto, Gota/Purinas (detecta extracto de levadura y E635), Embarazo y Niños, Piel Sensible/Acné INCI y Seguridad para Mascotas.\n"
    "• Lista Negra de Alérgenos: Agrega tus propios detonantes (maní, gluten, soya, lácteos) para alertas rojas al instante.\n"
    "• Comparador VS en Supermercado: Compara dos etiquetas lado a lado para elegir la opción más limpia.\n"
    "• Gabinete Rojo y Verde: Guarda tus favoritos y bloquea productos con ingredientes indeseados.\n\n"
    "PLANES TRANSPARENTES\n"
    "• Gratis siempre: 10 escaneos offline al día, cero anuncios, sin registro.\n"
    "• PureScan Pro: Mensual, Anual (con prueba gratis de 3 días y recordatorio local el día 2) o Compra Única de por vida.\n\n"
    "Referencia educativa basada en estándares públicos FDA/EFSA/INCI/AAFCO; no sustituye consejo médico.\n"
    "Privacidad: https://a3152557994-ship-it.github.io/purescan/privacy.html\n"
    "Términos (EULA): https://a3152557994-ship-it.github.io/purescan/terms.html"
)

FR_CA_DESC = (
    "Fatigué des applications qui affichent « Code-barres introuvable » sur les produits locaux, cosmétiques ou croquettes—ou qui imposent publicités et comptes ?\n\n"
    "PureScan lit directement la liste des ingrédients en 0,3 s grâce à Apple Vision OCR 100% hors ligne sur votre iPhone. Zéro publicité, zéro compte, zéro transfert dans le nuage.\n\n"
    "FONCTIONNALITÉS CLÉS\n"
    "• Lecture OCR hors ligne instantanée : Scannez aliments, soins INCI, nourriture pour chats/chiens ou captures d'écran même sans réseau en magasin.\n"
    "• 6 Radars personnalisés : Additifs, Faible en sucre/Keto, Goutte/Purines (extrait de levure & E635), Maternité & Enfants, Peaux sensibles/Acné INCI et Sécurité animale.\n"
    "• Liste noire d'allergènes : Ajoutez arachides, gluten, soya ou produits laitiers pour une alerte rouge immédiate.\n"
    "• Duel VS en épicerie : Comparez deux étiquettes côte à côte en 1 seconde.\n\n"
    "ACCÈS TRANSPARENT\n"
    "• Gratuit : 10 scans hors ligne par jour, sans pub ni compte.\n"
    "• PureScan Pro : Mensuel, Annuel (essai gratuit de 3 jours avec rappel local au jour 2) ou Achat unique à vie.\n\n"
    "Référence éducative basée sur les normes publiques FDA/EFSA/INCI/AAFCO ; ne remplace pas un avis médical.\n"
    "Confidentialité : https://a3152557994-ship-it.github.io/purescan/privacy.html\n"
    "Conditions (EULA) : https://a3152557994-ship-it.github.io/purescan/terms.html"
)

PT_BR_DESC = (
    "Cansado de aplicativos que mostram 'Código de barras não encontrado' em produtos locais, importados, cosméticos ou rações—ou exigem login e enchem a tela de anúncios?\n\n"
    "O PureScan lê diretamente a lista de ingredientes em 0,3s usando Apple Vision OCR 100% offline no seu iPhone. Zero anúncios, zero contas, zero envio à nuvem.\n\n"
    "RECURSOS PRINCIPAIS\n"
    "• OCR Offline Instantâneo: Escaneie alimentos, cosméticos INCI, rações para cães e gatos ou capturas de tela mesmo sem sinal no supermercado.\n"
    "• 6 Radares Personalizados: Aditivos, Baixo Açúcar/Keto, Gota/Purinas, Gestantes e Crianças, Pele Sensível/Acne INCI e Segurança Pet.\n"
    "• Lista Negra de Alérgenos: Cadastre amendoim, glúten, soja ou leite para alertas instantâneos.\n"
    "• Comparação VS Lado a Lado: Compare dois produtos e descubra o rótulo mais limpo em 1 segundo.\n\n"
    "PLANOS TRANSPARENTES\n"
    "• Grátis para sempre: 10 scans offline/dia, sem anúncios.\n"
    "• PureScan Pro: Mensal, Anual (teste grátis de 3 dias com lembrete no dia 2) ou Vitalício (pagamento único).\n\n"
    "Uso educativo baseado em referências públicas FDA/EFSA/INCI/AAFCO; não substitui orientação médica.\n"
    "Privacidade: https://a3152557994-ship-it.github.io/purescan/privacy.html\n"
    "Termos (EULA): https://a3152557994-ship-it.github.io/purescan/terms.html"
)

KO_DESC = (
    "바코드 인식 실패, 강제 로그인, 팝업 광고로 지치셨나요?\n\n"
    "PureScan은 Apple Vision 온디바이스 OCR을 사용해 식품 원재료명, 화장품 INCI 전성분, 반려동물 사료 성분표를 100% 오프라인으로 0.3초 만에 분석합니다. 광고 없음, 계정 없음, 클라우드 업로드 없음!\n\n"
    "주요 기능\n"
    "• 바코드 없이 즉시 오프라인 성분 OCR: 마트 지하, 수입 식품, 화장품, 고양이/강아지 사료, 온라인 쇼핑 스크린샷까지 즉시 스캔.\n"
    "• 6가지 맞춤 건강 레이더: 식품 첨가물, 저당/키토, 통풍/고퓨린(효모추출물·E635 감지), 임산부/육아, 민감성·여드름 피부 INCI, 반려동물 안전.\n"
    "• 개인 알레르기 블랙리스트: 땅콩, 글루텐, 대두, 유제품 등 나만의 주의 성분을 등록하면 즉시 경고.\n"
    "• 마트 1:1 VS 성분 비교: 두 제품을 나란히 비교해 더 깨끗한 제품을 1초 만에 선택.\n\n"
    "투명한 요금제\n"
    "• 무료 버전: 매일 10회 오프라인 스캔, 영구 광고 없음.\n"
    "• PureScan Pro: 월간, 연간(3일 무료 체험 + 2일차 갱신 알림), 또는 평생 1회 결제.\n\n"
    "FDA/EFSA/INCI/AAFCO 공개 기준 참고용이며 의학적 조언을 대체하지 않습니다.\n"
    "개인정보처리방침: https://a3152557994-ship-it.github.io/purescan/privacy.html\n"
    "이용약관: https://a3152557994-ship-it.github.io/purescan/terms.html"
)

VI_DESC = (
    "Chán cảnh quét mã vạch không ra sản phẩm, bắt đăng nhập hay tràn ngập quảng cáo?\n\n"
    "PureScan đọc trực tiếp bảng thành phần bằng Apple Vision OCR 100% ngoại tuyến ngay trên iPhone trong 0,3 giây. Không quảng cáo, không tài khoản, không tải ảnh lên đám mây!\n\n"
    "TÍNH NĂNG NỔI BẬT\n"
    "• Quét OCR ngoại tuyến không cần mã vạch: Thực phẩm, hàng nhập khẩu, mỹ phẩm INCI, thức ăn chó mèo hoặc ảnh chụp màn hình.\n"
    "• 6 Radar sức khỏe cá nhân hóa: Phụ gia thực phẩm, Ít đường/Keto, Gout/Purine, Mẹ & Bé, Da nhạy cảm/Mụn INCI và An toàn thú cưng.\n"
    "• Danh sách dị ứng tùy chỉnh: Thêm đậu phộng, gluten, đậu nành, sữa để nhận cảnh báo đỏ ngay lập tức.\n"
    "• So sánh VS tại siêu thị: Đối chiếu 2 nhãn sản phẩm song song để chọn loại sạch hơn trong 1 giây.\n\n"
    "MINH BẠCH & CÔNG BẰNG\n"
    "• Miễn phí: 10 lượt quét ngoại tuyến mỗi ngày, vĩnh viễn không quảng cáo.\n"
    "• PureScan Pro: Gói Tháng, Gói Năm (dùng thử 3 ngày miễn phí + nhắc lịch ngày thứ 2), hoặc Mua trọn đời một lần.\n\n"
    "Thông tin tham khảo theo tiêu chuẩn công khai FDA/EFSA/INCI/AAFCO; không thay thế tư vấn y tế.\n"
    "Quyền riêng tư: https://a3152557994-ship-it.github.io/purescan/privacy.html\n"
    "Điều khoản: https://a3152557994-ship-it.github.io/purescan/terms.html"
)

DE_DESC = (
    "Genug von Scanner-Apps, die „Barcode nicht gefunden“ melden, ein Konto verlangen oder Werbung einblenden?\n\n"
    "PureScan liest Zutatenlisten direkt mit 100% lokaler Apple Vision OCR auf deinem iPhone – ohne Cloud, ohne Tracking, ohne Werbung und sogar ohne Empfang im Supermarkt!\n\n"
    "HAUPTFUNKTIONEN\n"
    "• Sofortige Offline-OCR statt lückenhafter Barcode-Datenbanken: Scanne Lebensmittel, Eigenmarken, Kosmetik (INCI), Hunde- & Katzenfutter oder Screenshots in 0,3 Sekunden.\n"
    "• 6 Persönliche Gesundheits-Radare: Zusatzstoffe & E-Nummern, Wenig Zucker/Keto, Gicht/Purin (erkennt Hefeextrakt & E635), Schwangerschaft & Kinder, Sensible Haut/Akne (INCI) und Tierfutter-Check.\n"
    "• Eigene Allergen-Blacklist: Hinterlege Erdnüsse, Gluten, Soja oder Milch für sofortige Warnhinweise.\n"
    "• Supermarkt VS-Vergleich: Vergleiche zwei Produkte direkt nebeneinander und erkenne die sauberere Wahl.\n\n"
    "FAIRE PREISE & EINMALKAUF\n"
    "• Dauerhaft kostenlos: 10 Offline-Scans pro Tag, garantiert werbefrei und ohne Login.\n"
    "• PureScan Pro: Einmaliger Lifetime-Kauf ohne Abo, flexibel monatlich oder jährlich (inkl. 3 Tage kostenlos testen mit Erinnerung an Tag 2).\n\n"
    "Hinweis: Bildungs- und Orientierungshilfe nach öffentlichen EFSA/FDA/INCI/AAFCO-Quellen, keine medizinische Beratung.\n"
    "Datenschutz: https://a3152557994-ship-it.github.io/purescan/privacy.html\n"
    "Nutzungsbedingungen: https://a3152557994-ship-it.github.io/purescan/terms.html"
)

JA_DESC = (
    "バーコード未登録で調べられない、強制ログインや全面広告にイライラする——そんな成分チェックアプリの不満を解消しました。\n\n"
    "PureScanはApple純正のオンデバイスVision OCRで、パッケージ裏面の原材料・成分表示を0.3秒で直接スキャン。完全オフライン、広告ゼロ、アカウント不要で地下スーパーでもサクサク動作します。\n\n"
    "主な機能\n"
    "• バーコード不要のオフライン成分OCR：食品、輸入菓子、化粧品INCI成分、キャットフード・ドッグフード、通販のスクリーンショットまで幅広く対応。\n"
    "• 6つのパーソナル健康レーダー：食品添加物、糖質制限、痛風・プリン体（酵母エキス・核酸系調味料を検知）、妊娠中・キッズ、敏感肌・ニキビ化粧品INCI、ペットフード安全。\n"
    "• マイ・アレルゲン登録：ピーナッツ、グルテン、大豆、乳成分など避けたい成分を登録して即アラート。\n"
    "• スーパーVS比較：2つの商品を並べて、よりシンプルな原材料の勝者を1秒で判定。\n\n"
    "安心・透明な料金\n"
    "• 無料版：毎日10回までオフラインスキャン可能、永久広告なし。\n"
    "• PureScan Pro：月額、年額（3日間無料トライアル＋2日目の事前リマインド通知付き）、または一度払いの買い切り生涯プラン。\n\n"
    "※公的基準（FDA/EFSA/INCI/AAFCO等）に基づく日常の参考情報であり、医療助言ではありません。\n"
    "プライバシーポリシー：https://a3152557994-ship-it.github.io/purescan/privacy.html\n"
    "利用規約：https://a3152557994-ship-it.github.io/purescan/terms.html"
)

EN_GB_DESC = (
    "Tired of ingredient scanner apps failing with 'Barcode Not Found' on UK supermarket own-brands, imported snacks, skincare or pet food—or locking you behind logins and ads?\n\n"
    "PureScan reads the actual ingredients list directly using 100% on-device Apple Vision OCR. Zero ads, zero accounts, zero cloud uploads—works instantaneously even in aisles with zero mobile signal!\n\n"
    "KEY FEATURES\n"
    "• Instant Offline Label OCR (No Barcode Database Limits): Scan food packaging, ultra-processed foods (UPF), E-numbers, skincare INCI labels, cat/dog kibble, or online shopping screenshots in 0.3 seconds.\n"
    "• 6 Personalised Health & Safety Radars: Clean Additives & E-Numbers, Low Sugar/Keto, Gout/High Purine (spots Yeast Extract & E635), Mum & Kids, Sensitive/Acne Skincare INCI, and Pet Food Safety.\n"
    "• Custom Allergen Blacklist: Add your own triggers (Peanut, Gluten, Soya, Dairy) for instant red alerts.\n"
    "• Supermarket VS Showdown: Compare two yoghurts, breads, or pet foods side-by-side to spot the cleaner choice in 1 second.\n\n"
    "FAIR & TRANSPARENT PRO ACCESS\n"
    "• Free forever: 10 offline scans/day, zero ads, no login required.\n"
    "• PureScan Pro: Monthly, Annual (3-day free trial + built-in Day-2 local reminder), or Pay-Once Lifetime.\n\n"
    "Educational reference only based on public EFSA/FDA/INCI/AAFCO standards; not medical advice.\n"
    "Privacy Policy: https://a3152557994-ship-it.github.io/purescan/privacy.html\n"
    "Terms of Use (EULA): https://a3152557994-ship-it.github.io/purescan/terms.html"
)

# All 11 Locales: primary zh-Hans + 10-Locale US Cross-Localization & Global ASO Pack
LOCALIZATIONS: dict[str, dict[str, str]] = {
    "zh-Hans": {
        "name": "配料表扫描仪 - 配料照妖镜·添加剂避雷",
        "subtitle": "0广告离线拍配料 · 控糖痛风宝妈宠粮红黑榜",
        "keywords": "配料表查询,成分查查,食品添加剂,科技与狠活,零添加,控糖减肥,嘌呤高尿酸,护肤成分,猫粮狗粮,超市避雷,宝妈零食,离线识图",
        "promotionalText": "彻底告别摇一摇跳屏广告与条形码十样七样查不到！0.3秒本地离线拍配料表原文，控糖、痛风高尿酸、宝妈、敏肌护肤与猫狗粮一扫亮红灯。",
        "whatsNew": "v1.0.1 重磅升级：\n• 原生支持香港/台湾地道繁体中文界面与繁体配料表精准识别\n• 全新升级透明 3 天试用时间线与更清晰的 Pro 权益说明\n• 优化离线扫描体验与用户反馈入口，全程保持永久 0 广告、零数据收集",
        "description": ZH_HANS_DESC,
        "shotSource": "zh-Hans",
    },
    "en-US": {
        "name": "PureScan: Ingredient Scanner",
        "subtitle": "Offline Food & Skincare Label",
        "keywords": "ingredient,scanner,additive,toxin,sugar,keto,gout,purine,acne,skincare,pet,cat food,allergen,clean",
        "promotionalText": "No more 'barcode not found', forced logins, or pop-up ads! Scan ANY ingredient label 100% offline in 0.3s across Food, Skincare INCI, Gout/Purine & Pet Food.",
        "whatsNew": "What's New in v1.0.1:\n• Authentic Traditional Chinese (Hong Kong & Taiwan) UI & label OCR support\n• Transparent 3-day free trial timeline & clearer Pro options\n• Friendly feedback prompt & performance polish — still 100% offline with zero ads or tracking",
        "description": EN_DESC,
        "shotSource": "en-US",
    },
    "zh-Hant": {
        "name": "配料照妖鏡 - 食品添加劑與成分掃描儀",
        "subtitle": "0廣告離線拍配料 · 控糖痛風寵糧避雷",
        "keywords": "配料表,食品添加劑,成分查詢,控糖,痛風,嘌呤,護膚成分,貓糧狗糧,超市避雷,無添加,致敏原",
        "promotionalText": "告別條碼查不到與彈窗廣告！0.3秒本機離線辨識食品、護膚品INCI與貓狗糧成分表，控糖、痛風嘌呤、敏感肌與寵糧一拍即知。",
        "whatsNew": "v1.0.1 全新升級：\n• 原生支援香港及台灣地道繁體中文介面與繁體包裝成分表辨識\n• 升級透明 3 天免費試用時間軸與更清晰的 Pro 方案說明\n• 新增掃描後友善回饋入口與效能最佳化，維持 100% 本機離線、永久無廣告",
        "description": ZH_HANT_DESC,
        "shotSource": "en-US",
    },
    "es-MX": {
        "name": "PureScan: Escáner Ingredientes",
        "subtitle": "Comida, Piel y Mascotas OCR",
        "keywords": "escaner ingredientes,aditivos,azucar,gluten,alergenos,comida,cosmeticos,mascotas,saludable,sin",
        "promotionalText": "Sin anuncios ni cuentas. Escanea etiquetas de comida, cosméticos INCI y croquetas 100% offline en 0.3s para detectar azúcar oculta, aditivos y alérgenos.",
        "whatsNew": "Novedades v1.0.1:\n• Soporte completo para chino tradicional (HK/TW)\n• Línea de tiempo transparente de prueba gratis de 3 días\n• Mejoras de rendimiento y privacidad 100% offline sin anuncios",
        "description": ES_MX_DESC,
        "shotSource": "en-US",
    },
    "fr-CA": {
        "name": "PureScan: Scanner Ingrédients",
        "subtitle": "Aliments, Soins & Animaux OCR",
        "keywords": "ingredients,additifs,sucre,allergenes,sans gluten,cosmetiques,animaux,nutrition,sante,compare,scan",
        "promotionalText": "Zéro pub, zéro compte, 100% hors ligne ! Scannez toute étiquette alimentaire, cosmétique INCI ou croquette en 0,3 s pour repérer additifs et sucres cachés.",
        "whatsNew": "Nouveautés v1.0.1 :\n• Prise en charge authentique du chinois traditionnel\n• Calendrier transparent d'essai gratuit de 3 jours\n• Améliorations de rapidité et confidentialité 100% hors ligne",
        "description": FR_CA_DESC,
        "shotSource": "en-US",
    },
    "pt-BR": {
        "name": "PureScan: Label & Food Check",
        "subtitle": "OCR Additive & Allergen Reader",
        "keywords": "barcode,checker,reader,ocr,seed oil,preservative,dye,red 40,vegan,dairy,soy,nut,baby,grocery,healthy",
        "promotionalText": "Escaneie rótulos de alimentos, cosméticos INCI e rações 100% offline em 0,3s. Sem anúncios, sem login e sem erro de código de barras não encontrado.",
        "whatsNew": "Novidades v1.0.1:\n• Suporte nativo a chinês tradicional\n• Linha do tempo transparente de teste grátis de 3 dias\n• Melhorias gerais mantendo 100% de privacidade offline sem anúncios",
        "description": PT_BR_DESC,
        "shotSource": "en-US",
    },
    "ko": {
        "name": "PureScan: Cosmetic & Pet Check",
        "subtitle": "INCI, Pregnancy & Kibble OCR",
        "keywords": "cosmetic,inci,comedogenic,pregnancy,safe,dog,kibble,nutrition,ultra processed,hfcs,diet,성분,첨가물,화장품",
        "promotionalText": "광고 없이 100% 오프라인으로 식품 첨가물, 화장품 INCI 전성분, 반려동물 사료 원재료를 0.3초 만에 스캔하세요. 로그인 불필요.",
        "whatsNew": "v1.0.1 업데이트:\n• 정통 번체 중국어 지원 추가\n• 투명한 3일 무료 체험 안내 및 Pro 화면 개선\n• 100% 오프라인 무광고 성능 최적화",
        "description": KO_DESC,
        "shotSource": "en-US",
    },
    "vi": {
        "name": "PureScan: Chemical & Food OCR",
        "subtitle": "Harmful Additive & Diet Radar",
        "keywords": "chemical,harmful,toxic,beauty,makeup,lotion,paraben,sulfate,fragrance,msg,palm oil,trans fat,no ads",
        "promotionalText": "Quét thành phần thực phẩm, mỹ phẩm INCI và thức ăn thú cưng 100% ngoại tuyến trong 0.3 giây. Không quảng cáo, không cần đăng nhập, bảo mật tuyệt đối.",
        "whatsNew": "Có gì mới trong v1.0.1:\n• Hỗ trợ tiếng Trung phồn thể chuẩn\n• Hiển thị minh bạch lịch dùng thử miễn phí 3 ngày\n• Tối ưu hiệu năng, vẫn 100% ngoại tuyến và không quảng cáo",
        "description": VI_DESC,
        "shotSource": "en-US",
    },
    "de-DE": {
        "name": "PureScan: Zutaten & INCI Scan",
        "subtitle": "Offline ohne Abo-Zwang & Ads",
        "keywords": "zutaten,inhaltsstoffe,zusatzstoffe,e-nummern,zucker,allergene,kosmetik,inci,hundefutter,katzenfutter",
        "promotionalText": "100% offline auf deinem iPhone – ohne Cloud, ohne Konto, ohne Werbung! Scanne Zutatenlisten für Lebensmittel, Kosmetik (INCI) & Tierfutter in 0,3 Sekunden.",
        "whatsNew": "Neu in v1.0.1:\n• Unterstützung für traditionelles Chinesisch\n• Transparente 3-Tage-Test-Übersicht & Einmalkauf-Option\n• Leistungs- & Privatsphäre-Optimierungen (100% offline)",
        "description": DE_DESC,
        "shotSource": "en-US",
    },
    "ja": {
        "name": "PureScan: 食品添加物・成分スキャナー",
        "subtitle": "完全オフライン・広告なしで原材料チェック",
        "keywords": "食品添加物,原材料,成分チェッカー,無添加,糖質制限,プリン体,痛風,化粧品成分,敏感肌,キャットフード,ドッグフード,アレルギー,オフライン",
        "promotionalText": "広告ゼロ・ログイン不要・100%オフライン！食品の原材料、化粧品INCI成分、キャットフード・ドッグフードを0.3秒で解析し、添加物や隠れ糖質を瞬時に表示。",
        "whatsNew": "v1.0.1 の新機能：\n• 繁体字中国語（香港・台湾）に本格対応\n• 3日間無料トライアルの透明タイムラインと買い切り案内を改善\n• オフライン認識と使いやすさを向上（引き続き完全広告なし）",
        "description": JA_DESC,
        "shotSource": "en-US",
    },
    "en-GB": {
        "name": "PureScan: Food & E-Number Scan",
        "subtitle": "Offline UPF & Skincare Reader",
        "keywords": "e numbers,e-numbers,ultra processed,upf,food check,supermarket,skincare check,pet safety,allergies",
        "promotionalText": "Zero ads, zero cloud tracking, 100% offline. Scan any UK/EU food label, E-numbers, skincare INCI or pet kibble in 0.3s — no barcode database required.",
        "whatsNew": "What's New in v1.0.1:\n• Authentic Traditional Chinese (Hong Kong & Taiwan) UI & OCR support\n• Transparent 3-day free trial timeline & pay-once Lifetime clarity\n• Quick feedback prompt & performance improvements — still 100% offline with zero ads",
        "description": EN_GB_DESC,
        "shotSource": "en-US",
    },
}


def validate_metadata() -> None:
    us_english_slots = ["en-US", "pt-BR", "ko", "vi"]
    seen_en_terms: dict[str, str] = {}
    for loc, d in LOCALIZATIONS.items():
        assert len(d["name"]) <= 30, f"{loc} name too long ({len(d['name'])}): {d['name']}"
        assert len(d["subtitle"]) <= 30, f"{loc} subtitle too long ({len(d['subtitle'])}): {d['subtitle']}"
        assert len(d["keywords"]) <= 100, f"{loc} keywords too long ({len(d['keywords'])}): {d['keywords']}"
        assert len(d["promotionalText"]) <= 170, f"{loc} promo too long ({len(d['promotionalText'])})"
        assert len(d["whatsNew"]) >= 10, f"{loc} whatsNew missing"
        assert len(d["description"]) <= 4000, f"{loc} description too long ({len(d['description'])})"
        if loc in us_english_slots:
            for kw in [k.strip().lower() for k in d["keywords"].split(",") if k.strip()]:
                if kw.isascii():
                    assert kw not in seen_en_terms, f"Duplicate US-indexed keyword '{kw}' in {loc} and {seen_en_terms[kw]}"
                    seen_en_terms[kw] = loc
    print(f"✓ Validated all {len(LOCALIZATIONS)} locales (zero limit violations, zero duplicate US keywords)")


def b64u(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def make_jwt() -> str:
    header = b64u(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}, separators=(",", ":")).encode())
    now = int(time.time())
    payload = b64u(json.dumps({"iss": ISSUER_ID, "iat": now - 10, "exp": now + 900, "aud": "appstoreconnect-v1"}, separators=(",", ":")).encode())
    msg = f"{header}.{payload}".encode()
    der = subprocess.check_output(["openssl", "dgst", "-sha256", "-sign", KEY_PATH], input=msg)
    idx = 2 + ((der[1] & 0x7F) if (der[1] & 0x80) else 0)
    rlen = der[idx + 1]
    r = der[idx + 2 : idx + 2 + rlen].lstrip(b"\x00").rjust(32, b"\x00")
    idx = idx + 2 + rlen
    slen = der[idx + 1]
    s = der[idx + 2 : idx + 2 + slen].lstrip(b"\x00").rjust(32, b"\x00")
    return f"{header}.{payload}.{b64u(r + s)}"


def asc(method: str, path: str, body: dict | None = None) -> tuple[int, Any]:
    token = make_jwt()
    data = json.dumps(body).encode() if body is not None else None
    url = path if path.startswith("http") else f"https://api.appstoreconnect.apple.com{path}"
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as resp:
            raw = resp.read().decode()
            return resp.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, raw


def upload_screenshot(set_id: str, png: Path) -> None:
    raw = png.read_bytes()
    md5 = hashlib.md5(raw).hexdigest()
    st, res = asc("POST", "/v1/appScreenshots", {
        "data": {
            "type": "appScreenshots",
            "attributes": {"fileSize": len(raw), "fileName": png.name},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
        }
    })
    if st not in (200, 201) or not isinstance(res, dict):
        raise RuntimeError(f"Reserve screenshot {png.name} failed: {st} {res}")
    aid = res["data"]["id"]
    for op in res["data"]["attributes"].get("uploadOperations", []):
        chunk = raw[op["offset"] : op["offset"] + op["length"]]
        hdrs = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        urllib.request.urlopen(urllib.request.Request(op["url"], data=chunk, headers=hdrs, method=op["method"]), timeout=60).read()
    st_c, res_c = asc("PATCH", f"/v1/appScreenshots/{aid}", {
        "data": {"type": "appScreenshots", "id": aid, "attributes": {"uploaded": True, "sourceFileChecksum": md5}}
    })
    if st_c not in (200, 204):
        raise RuntimeError(f"Commit screenshot {png.name} failed: {st_c} {res_c}")


def ensure_shots(vloc_id: str, display_type: str, folder: Path, loc: str) -> None:
    pngs = sorted(folder.glob("*.png"))
    if not pngs:
        return
    _, sets = asc("GET", f"/v1/appStoreVersionLocalizations/{vloc_id}/appScreenshotSets")
    set_id = None
    for s in sets.get("data", []) if isinstance(sets, dict) else []:
        if s["attributes"]["screenshotDisplayType"] == display_type:
            set_id = s["id"]
            break
    if set_id:
        _, existing = asc("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots")
        exist_items = existing.get("data", []) if isinstance(existing, dict) else []
        if len(exist_items) >= len(pngs):
            print(f"    • {loc} {display_type}: {len(exist_items)} shots already present")
            return
        for item in exist_items:
            asc("DELETE", f"/v1/appScreenshots/{item['id']}")
    else:
        st, cset = asc("POST", "/v1/appScreenshotSets", {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display_type},
                "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": vloc_id}}},
            }
        })
        if st not in (200, 201):
            raise RuntimeError(f"Create screenshot set {loc}/{display_type} failed: {st} {cset}")
        set_id = cset["data"]["id"]

    for png in pngs:
        upload_screenshot(set_id, png)
    print(f"    ✓ {loc} {display_type}: uploaded {len(pngs)} shots from {folder.parent.name}")


def wait_for_valid_build(target_build: str, wait_secs: int = 600) -> str:
    print(f"[BUILD] Waiting for build {target_build} ({TARGET_VERSION}) to reach VALID...")
    deadline = time.time() + wait_secs
    while True:
        st, res = asc("GET", f"/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=10")
        if st == 200 and isinstance(res, dict):
            builds = res.get("data", [])
            summary = [(b["attributes"].get("version"), b["attributes"].get("processingState"), b["id"]) for b in builds]
            for b in builds:
                if b["attributes"].get("version") == target_build:
                    state = b["attributes"].get("processingState")
                    if state == "VALID":
                        print(f"  ✓ Build {target_build} is VALID ({b['id']})")
                        return b["id"]
                    if state in ("FAILED", "INVALID"):
                        raise RuntimeError(f"Build {target_build} failed processing: {b}")
            print(f"  ... builds so far: {summary}", flush=True)
        if time.time() >= deadline:
            raise TimeoutError(f"Timed out waiting for build {target_build} to reach VALID")
        time.sleep(20)


def ensure_version_101() -> str:
    _, vers = asc("GET", f"/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=10")
    for v in vers.get("data", []):
        if v["attributes"].get("versionString") == TARGET_VERSION:
            print(f"  ✓ Found existing version {TARGET_VERSION}: {v['id']} ({v['attributes'].get('appStoreState')})")
            return v["id"]

    st, created = asc("POST", "/v1/appStoreVersions", {
        "data": {
            "type": "appStoreVersions",
            "attributes": {
                "platform": "IOS",
                "versionString": TARGET_VERSION,
                "copyright": "2026 Yang He",
                "releaseType": "AFTER_APPROVAL",
            },
            "relationships": {
                "app": {"data": {"type": "apps", "id": APP_ID}},
            },
        }
    })
    if st not in (200, 201):
        raise RuntimeError(f"Failed creating version {TARGET_VERSION}: {st} {created}")
    ver_id = created["data"]["id"]
    print(f"  + Created iOS App Store Version {TARGET_VERSION}: {ver_id}")
    return ver_id


def get_editable_app_info_id() -> str:
    _, infos = asc("GET", f"/v1/apps/{APP_ID}/appInfos")
    data = infos.get("data", [])
    for info in data:
        state = info["attributes"].get("appStoreState")
        if state in ("PREPARE_FOR_SUBMISSION", "WAITING_FOR_REVIEW", "DEVELOPER_REJECTED", "REJECTED"):
            print(f"  ✓ Using editable appInfo {info['id']} ({state})")
            return info["id"]
    raise RuntimeError(f"No editable appInfo found: {[(x['id'], x['attributes'].get('appStoreState')) for x in data]}")


def sync_all_localizations(ver_id: str, info_id: str, upload_shots: bool) -> None:
    print(f"[ASO] Syncing {len(LOCALIZATIONS)} locales across appInfoLocalizations + appStoreVersionLocalizations...")
    _, info_locs = asc("GET", f"/v1/appInfos/{info_id}/appInfoLocalizations?limit=50")
    imap = {x["attributes"]["locale"]: x["id"] for x in info_locs.get("data", [])}

    # Pass 1: create/update all appInfoLocalizations first (Apple may auto-create matching version localizations)
    for loc, d in LOCALIZATIONS.items():
        iattrs = {
            "name": d["name"],
            "subtitle": d["subtitle"],
            "privacyPolicyUrl": URLS["privacy"],
        }
        if loc in imap:
            st_i, res_i = asc("PATCH", f"/v1/appInfoLocalizations/{imap[loc]}", {
                "data": {"type": "appInfoLocalizations", "id": imap[loc], "attributes": iattrs}
            })
        else:
            st_i, res_i = asc("POST", "/v1/appInfoLocalizations", {
                "data": {
                    "type": "appInfoLocalizations",
                    "attributes": {"locale": loc, **iattrs},
                    "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info_id}}},
                }
            })
        if st_i not in (200, 201, 204):
            raise RuntimeError(f"appInfoLocalization {loc} failed ({st_i}): {res_i}")

    # Pass 2: refresh version localizations after appInfoLocalizations are in place, then create/patch + sync screenshots
    _, ver_locs = asc("GET", f"/v1/appStoreVersions/{ver_id}/appStoreVersionLocalizations?limit=50")
    vmap = {x["attributes"]["locale"]: x["id"] for x in ver_locs.get("data", [])}

    for loc, d in LOCALIZATIONS.items():
        vattrs = {
            "description": d["description"],
            "keywords": d["keywords"],
            "promotionalText": d["promotionalText"],
            "whatsNew": d["whatsNew"],
            "supportUrl": URLS["support"],
            "marketingUrl": URLS["marketing"],
        }
        if loc in vmap:
            vloc_id = vmap[loc]
            st_v, res_v = asc("PATCH", f"/v1/appStoreVersionLocalizations/{vloc_id}", {
                "data": {"type": "appStoreVersionLocalizations", "id": vloc_id, "attributes": vattrs}
            })
            if st_v not in (200, 204):
                raise RuntimeError(f"PATCH versionLoc {loc} failed ({st_v}): {res_v}")
        else:
            st_v, res_v = asc("POST", "/v1/appStoreVersionLocalizations", {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "attributes": {"locale": loc, **vattrs},
                    "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}}},
                }
            })
            if st_v == 409:
                _, ver_locs_retry = asc("GET", f"/v1/appStoreVersions/{ver_id}/appStoreVersionLocalizations?limit=50")
                vmap = {x["attributes"]["locale"]: x["id"] for x in ver_locs_retry.get("data", [])}
                vloc_id = vmap[loc]
                st_v, res_v = asc("PATCH", f"/v1/appStoreVersionLocalizations/{vloc_id}", {
                    "data": {"type": "appStoreVersionLocalizations", "id": vloc_id, "attributes": vattrs}
                })
                if st_v not in (200, 204):
                    raise RuntimeError(f"PATCH-after-409 versionLoc {loc} failed ({st_v}): {res_v}")
            elif st_v not in (200, 201):
                raise RuntimeError(f"POST versionLoc {loc} failed ({st_v}): {res_v}")
            else:
                vloc_id = res_v["data"]["id"]

        print(f"  ✓ {loc:7s} | name({len(d['name']):2d}): {d['name']} | kw({len(d['keywords']):3d})", flush=True)

        if upload_shots:
            src_dir = SHOT_ROOT / d["shotSource"]
            ensure_shots(vloc_id, "APP_IPHONE_65", src_dir / "iphone65", loc)
            ensure_shots(vloc_id, "APP_IPAD_PRO_3GEN_129", src_dir / "ipad13", loc)

    # Update review notes for 1.0.1
    review_notes = (
        "PureScan v1.0.1 update:\n"
        "- Added authentic Traditional Chinese (Hong Kong & Taiwan) UI and Traditional Chinese OCR ingredient matching.\n"
        "- Added a respectful happy-path feedback prompt after the 2nd completed scan (routes positive responses to Apple's native requestReview() with a 90-day throttle, or feedback to email).\n"
        "- Upgraded PaywallView with a transparent 3-day free trial timeline and clearer lifetime/subscription disclosures using our existing approved StoreKit 2 product IDs (com.yanghe.purescan.pro.lifetime, com.yanghe.purescan.pro.yearly, com.yanghe.purescan.pro.monthly).\n"
        "- 100% offline on-device Vision OCR, zero ads, zero login, zero network telemetry (Data Not Collected).\n\n"
        "Quick testing without physical packages: tap 'Try Live Demo Scan' or any of the 8 built-in label samples on the Scan tab."
    )
    rattrs = {
        "contactFirstName": "Yang",
        "contactLastName": "He",
        "contactPhone": "+86 196 3394 8182",
        "contactEmail": "a3152557994@gmail.com",
        "demoAccountRequired": False,
        "notes": review_notes,
    }
    st_r, res_r = asc("GET", f"/v1/appStoreVersions/{ver_id}/appStoreReviewDetail")
    if st_r == 200 and isinstance(res_r, dict) and res_r.get("data"):
        rd_id = res_r["data"]["id"]
        asc("PATCH", f"/v1/appStoreReviewDetails/{rd_id}", {"data": {"type": "appStoreReviewDetails", "id": rd_id, "attributes": rattrs}})
    else:
        asc("POST", "/v1/appStoreReviewDetails", {
            "data": {"type": "appStoreReviewDetails", "attributes": rattrs, "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}}}}
        })
    print("  ✓ Updated App Store Review Details for 1.0.1")


def submit_version_for_review(ver_id: str) -> str:
    print("[SUBMIT] Submitting PureScan 1.0.1 to Apple App Review...")
    # Reuse or cancel any stale READY_FOR_REVIEW / UNRESOLVED_ISSUES submission if present
    _, existing_rs = asc("GET", f"/v1/apps/{APP_ID}/reviewSubmissions?filter[platform]=IOS&limit=5")
    rs_id = None
    for rs in existing_rs.get("data", []) if isinstance(existing_rs, dict) else []:
        state = rs["attributes"].get("state")
        if state in ("READY_FOR_REVIEW", "UNRESOLVED_ISSUES"):
            rs_id = rs["id"]
            print(f"  • Reusing open reviewSubmission {rs_id} ({state})")
            break

    if not rs_id:
        st_rs, res_rs = asc("POST", "/v1/reviewSubmissions", {
            "data": {
                "type": "reviewSubmissions",
                "attributes": {"platform": "IOS"},
                "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
            }
        })
        if st_rs not in (200, 201):
            raise RuntimeError(f"POST /v1/reviewSubmissions failed: {st_rs} {res_rs}")
        rs_id = res_rs["data"]["id"]
        print(f"  + Created reviewSubmission: {rs_id}")

    # Check if version item already attached
    _, cur_items = asc("GET", f"/v1/reviewSubmissions/{rs_id}/items")
    has_ver = any(
        item.get("relationships", {}).get("appStoreVersion", {}).get("data", {}).get("id") == ver_id
        for item in (cur_items.get("data", []) if isinstance(cur_items, dict) else [])
    )
    if not has_ver:
        st_i, res_i = asc("POST", "/v1/reviewSubmissionItems", {
            "data": {
                "type": "reviewSubmissionItems",
                "relationships": {
                    "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": rs_id}},
                    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}},
                },
            }
        })
        if st_i not in (200, 201):
            raise RuntimeError(f"POST /v1/reviewSubmissionItems failed: {st_i} {res_i}")
        print(f"  + Attached version {ver_id} to reviewSubmission {rs_id}")

    st_sub, res_sub = asc("PATCH", f"/v1/reviewSubmissions/{rs_id}", {
        "data": {"type": "reviewSubmissions", "id": rs_id, "attributes": {"submitted": True}}
    })
    if st_sub not in (200, 201):
        raise RuntimeError(f"PATCH /v1/reviewSubmissions/{rs_id} submit failed: {st_sub} {res_sub}")

    print(f"  🚀 Submitted reviewSubmission {rs_id} -> {res_sub['data']['attributes'].get('state')}")

    # Verify version state
    time.sleep(3)
    _, ver_check = asc("GET", f"/v1/appStoreVersions/{ver_id}?include=build")
    v_state = ver_check["data"]["attributes"].get("appStoreState")
    b_data = ver_check["data"].get("relationships", {}).get("build", {}).get("data")
    print(f"  ✅ Verified Version {TARGET_VERSION} State: {v_state} | Build: {b_data}")
    return rs_id


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--wait-build", action="store_true")
    parser.add_argument("--sync", action="store_true")
    parser.add_argument("--no-shots", action="store_true")
    parser.add_argument("--submit", action="store_true")
    args = parser.parse_args()

    validate_metadata()
    if args.validate_only:
        return 0

    build_id = None
    if args.wait_build:
        build_id = wait_for_valid_build(TARGET_BUILD, wait_secs=720)

    ver_id = ensure_version_101()

    if build_id:
        st_b, res_b = asc("PATCH", f"/v1/appStoreVersions/{ver_id}/relationships/build", {
            "data": {"type": "builds", "id": build_id}
        })
        if st_b not in (200, 204):
            raise RuntimeError(f"Attach build {build_id} failed: {st_b} {res_b}")
        print(f"  ✓ Attached Build {TARGET_BUILD} ({build_id}) to version {TARGET_VERSION}")

    if args.sync:
        info_id = get_editable_app_info_id()
        sync_all_localizations(ver_id, info_id, upload_shots=not args.no_shots)

    if args.submit:
        rs_id = submit_version_for_review(ver_id)
        print(f"\nDONE: Submission ID = {rs_id}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
