# 🪞 MirrorMan

> آینه‌یاب و میرور منیجر حرفه‌ای برای توسعه‌دهندگان در شبکه‌های محدود

[![Version](https://img.shields.io/badge/version-1.0.0-blue?style=flat-square)](https://github.com/solamente0/mirrorman)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh%20%7C%20sh-orange?style=flat-square)]()
[![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue?style=flat-square)]()

---

## ✨ قابلیت‌ها

- 🌐 **پشتیبانی از زبان‌های متعدد**: Python، Node.js، Docker، Go، Rust، Java، Ruby، Linux
- ⚡ **اسکنر سرعت هوشمند**: بنچمارک واقعی میرورها و پیشنهاد سریع‌ترین
- 🖥️ **چند پلتفرمی**: Linux، macOS، Windows (PowerShell + WSL)
- 📌 **تنظیم دائم یا موقت**: اعمال میرور برای کل سیستم یا فقط یک دستور
- 🌍 **اسکنر DNS**: تست سرعت DNS سرورهای مختلف
- ⭐ **میرور سفارشی**: تعریف میرور اختصاصی سازمان یا شخصی
- 🔄 **بازگشت آسان**: ریست به رجیستری پیش‌فرض با یک دستور
- 💾 **داده‌های JSON**: ساختار ساده برای به‌روزرسانی و افزودن میرور جدید
- 🎨 **رابط وب زیبا**: HTML standalone با طراحی تاریک حرفه‌ای
- 🔤 **پشتیبانی فارسی**: رابط وب کاملاً فارسی (RTL)

---

## 📦 ساختار پروژه

```
mirrorman/
├── bin/
│   ├── mirrorman.sh        ← اسکریپت اصلی (Linux/macOS/WSL/Git Bash)
│   └── mirrorman.ps1       ← نسخه PowerShell (Windows)
├── data/
│   └── mirrors.json        ← پایگاه داده میرورها (ویرایش کنید!)
├── web/
│   └── index.html          ← رابط وب standalone
├── README.md
├── CONTRIBUTING.md
├── CHANGELOG.md
└── LICENSE
```

---

## 🚀 نصب سریع

### Linux / macOS

```bash
# کلون پروژه
git clone https://github.com/solamente0/mirrorman.git
cd mirrorman

# اجراپذیر کردن
chmod +x bin/mirrorman.sh

# لینک سراسری (اختیاری)
sudo ln -sf "$(pwd)/bin/mirrorman.sh" /usr/local/bin/mirrorman

# نصب alias های پیشنهادی
mirrorman alias install
source ~/.bashrc  # یا ~/.zshrc
```

### Windows (PowerShell)

```powershell
# کلون پروژه
git clone https://github.com/solamente0/mirrorman.git
cd mirrorman

# اجرا مستقیم
.\bin\mirrorman.ps1 help

# یا اضافه کردن به PATH در PowerShell Profile:
# $env:PATH += ";C:\path\to\mirrorman\bin"
```

### رابط وب

فایل `web/index.html` را در مرورگر باز کنید — بدون نیاز به سرور!

---

## 📖 دستورات

### نمایش همه میرورها

```bash
mirrorman list
mirrorman list javascript    # فیلتر بر اساس دسته
mirrorman list python        # فیلتر بر اساس زبان
```

### اسکن و بنچمارک

```bash
mirrorman scan python        # پیدا کردن سریع‌ترین میرور Python
mirrorman scan npm           # اسکن npm
mirrorman scan --dns         # تست سرعت DNS سرورها
```

### اعمال میرور

```bash
# دائمی (ذخیره در config سیستم)
mirrorman set python tsinghua
mirrorman set npm taobao
mirrorman set golang goproxy_cn
mirrorman set docker dockerproxy

# موقت (فقط برای این session ترمینال)
mirrorman set python aliyun --temp
```

### استفاده یک‌باره (بدون تغییر تنظیمات)

```bash
# دستور با میرور موقت
mirrorman use python tsinghua -- pip install requests numpy pandas
mirrorman use npm taobao -- npm install express react
mirrorman use golang goproxy_cn -- go get golang.org/x/tools

# Alias های سریع (بعد از `mirrorman alias install`)
pip-cn install requests
npm-cn install express
go-cn golang.org/x/tools
```

### وضعیت و ریست

```bash
mirrorman status             # نمایش میرورهای فعال
mirrorman reset python       # بازگشت به PyPI اصلی
mirrorman reset npm          # بازگشت به registry.npmjs.org
```

### میرور سفارشی

```bash
# افزودن میرور اختصاصی
mirrorman add python corporate "PyPI شرکت ما" https://pypi.mycompany.com/simple/
mirrorman add npm internal "npm داخلی" https://npm.mycompany.com/

# سپس مثل بقیه استفاده کنید
mirrorman set python corporate
```

### Alias ها

```bash
mirrorman alias show         # نمایش alias های موجود
mirrorman alias install      # نصب در .bashrc / .zshrc
```

---

## ⚙️ پیکربندی

فایل‌های تنظیمات در `~/.config/mirrorman/` (Linux/macOS) یا `%APPDATA%\mirrorman\` (Windows) ذخیره می‌شوند:

| فایل | توضیح |
|------|-------|
| `applied.json` | میرورهای فعال‌شده |
| `custom_mirrors.json` | میرورهای سفارشی کاربر |
| `mirrorman.log` | لاگ عملیات |

---

## 🔧 افزودن میرور جدید به `data/mirrors.json`

```json
{
  "languages": {
    "python": {
      "mirrors": [
        {
          "id": "mymirror",
          "name": "میرور من",
          "url": "https://pypi.example.com/simple/",
          "country": "IR",
          "flag": "🇮🇷",
          "speed": "fast",
          "last_updated": "2025-01-01",
          "notes": "توضیح اختیاری"
        }
      ]
    }
  }
}
```

---

## 🌍 زبان‌های پشتیبانی شده

| زبان/ابزار | دستور | متغیر محیطی |
|-----------|-------|-------------|
| Python (pip) | `pip install` | `PIP_INDEX_URL` |
| Node.js (npm) | `npm install` | `npm_config_registry` |
| Docker | `docker pull` | `daemon.json` |
| Go (modules) | `go get` | `GOPROXY` |
| Rust (Cargo) | `cargo add` | `~/.cargo/config.toml` |
| Java (Maven) | `mvn install` | `~/.m2/settings.xml` |
| Ruby (gems) | `gem install` | `gem sources` |
| Linux (apt/yum) | `apt install` | `sources.list` |

---

## 📋 پیش‌نیازها

| ابزار | وضعیت |
|-------|--------|
| `bash` 4.0+ یا `zsh` | الزامی |
| `curl` یا `wget` | برای اسکن سرعت |
| `python3` | برای پارس JSON (اگر `jq` نیست) |
| `jq` | اختیاری (پارس سریع‌تر JSON) |
| PowerShell 5.1+ | فقط برای Windows |

---

## 🤝 مشارکت

[CONTRIBUTING.md](CONTRIBUTING.md) را مطالعه کنید.

---

## 💜 حمایت مالی

MirrorMan با عشق و برای توسعه‌دهندگانی ساخته شده که زیر سایه محدودیت‌های شبکه کار می‌کنند.
اگر این ابزار کمکتان کرد، با یک حمایت کوچک این پروژه را زنده نگه دارید:

### 💳 کارت بانکی (ایران)

```
6037-9919-2249-1257
بانک ملی — امید ناطقی
```

### ⚡ زرین‌پال

**[zarinpal.al/omidnateghi.ir](https://zarinpal.al/omidnateghi.ir)**

### ₿ رمزارز (Crypto)
Trust Wallet
🚀 TRON (TRX & USDT)
🌐 Network: TRC20
🔗 Address: TPyyZZNrc9naqKzPYEzdmzouAHoXh7M1EA

🚀 BITCOIN (BIT)
🌐 Network: TRC20
🔗 Address: bc1qfw0cmg30lgard7jx66mh85l0ea7kvt38tppe57

🚀 ETHERIUM (ETH)
🌐 Network: ERC20
🔗 Address: 0x1410F99B230E87833A7A9E3b4c6ed5C5Cd57A5D8

---

## 👨‍💻 توسعه‌دهنده

**امید ناطقی**
🌐 [solamente0.github.io](https://solamente0.github.io)

---

## 📄 مجوز

[MIT License](LICENSE) — استفاده آزاد، تجاری و غیرتجاری
