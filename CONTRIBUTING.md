# 🤝 راهنمای مشارکت در MirrorMan

از علاقه شما برای مشارکت در MirrorMan متشکریم! این سند نحوه مشارکت را توضیح می‌دهد.

---

## 🌱 انواع مشارکت

### ۱. افزودن میرور جدید

ساده‌ترین کمک: اضافه کردن میرور معتبر به `data/mirrors.json`.

**فرمت:**
```json
{
  "id": "unique_id",
  "name": "نام نمایشی میرور",
  "url": "https://mirror.example.com/path/",
  "country": "XX",
  "flag": "🏳️",
  "speed": "fast | medium | slow",
  "last_updated": "YYYY-MM-DD",
  "notes": "توضیح اختیاری"
}
```

**قوانین:**
- `id` باید منحصربه‌فرد و lowercase باشد، فقط `a-z0-9_`
- `url` باید با `https://` شروع شده و با `/` ختم شود
- `last_updated` باید تاریخ آخرین تست واقعی باشد
- میرورهای غیرفعال یا ناپایدار اضافه نکنید

### ۲. افزودن زبان/ابزار جدید

برای اضافه کردن یک زبان برنامه‌نویسی جدید، ساختار زیر را در `languages` اضافه کنید:

```json
"newlang": {
  "name": "نام کامل (package manager)",
  "icon": "🆕",
  "category": "general | javascript | devops | systems | jvm | scripting | os",
  "env_var": "VARIABLE_NAME",
  "config_file": "~/.config/file",
  "config_file_win": "%APPDATA%\\file",
  "default_registry": "https://original.registry.com/",
  "mirrors": [...],
  "usage": {
    "temp": "command {package} --flag {mirror_url}",
    "permanent_linux": "command to set permanently on Linux/macOS",
    "permanent_win": "command to set permanently on Windows"
  }
}
```

همچنین باید پشتیبانی آن را در `bin/mirrorman.sh` در تابع `_apply_mirror` اضافه کنید.

### ۳. گزارش باگ

Issue باز کنید با:
- سیستم عامل و نسخه
- نسخه Shell
- دستور اجرا شده
- خروجی خطا

### ۴. بهبود کد

- قبل از PR، issue باز کنید تا بحث شود
- کد باید با `bash 4.0+` سازگار باشد
- از `set -euo pipefail` پیروی کنید
- توابع جدید باید مستند شوند

### ۵. بهبود رابط وب

فایل `web/index.html` یک فایل standalone کامل است. هیچ dependency خارجی ندارد.

---

## 🔄 فرآیند Pull Request

1. Fork کنید
2. Branch جدید: `git checkout -b feat/add-conda-mirrors`
3. تغییرات را با پیام واضح commit کنید
4. PR باز کنید با توضیح کامل

**فرمت پیام commit:**
```
type(scope): description

feat(data): add conda mirrors for Python
fix(bash): handle spaces in mirror URLs
docs(readme): update Windows installation guide
```

---

## 📋 چک‌لیست قبل از PR

- [ ] میرورها تست شده‌اند (واقعاً در دسترس هستند)
- [ ] JSON معتبر است (`python3 -m json.tool data/mirrors.json`)
- [ ] در Linux و macOS تست شده
- [ ] در صورت تغییر bash، با `bash --norc bin/mirrorman.sh` تست شده
- [ ] README به‌روز شده (در صورت نیاز)

---

## 💡 اولویت‌های فعلی

- [ ] افزودن میرور برای `pip` از اروپا
- [ ] پشتیبانی از `conda`/`mamba`
- [ ] پشتیبانی از `composer` (PHP)
- [ ] پشتیبانی از `nuget` (.NET)
- [ ] پشتیبانی از `swift package`
- [ ] تست خودکار با GitHub Actions
- [ ] اضافه کردن میرورهای ایرانی (در صورت وجود)

---

با سوال یا پیشنهاد، Issue باز کنید. ممنون! 🙏
