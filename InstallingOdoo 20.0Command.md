<div dir="rtl" align="right">

# دليل تثبيت Odoo 20 باستخدام Docker Compose

**Odoo 20 · PostgreSQL 18 · Docker Compose · دعم Traefik اختياري**

دليل عملي لتثبيت Odoo 20 وإدارته على Ubuntu/Linux، مع خيار تشغيل أكثر من
نسخة على الخادم نفسه.

[ابدأ التثبيت](#-التثبيت-السريع) · [تشغيل نسخ متعددة](#-تشغيل-أكثر-من-نسخة) ·
[إدارة الحاويات](#-إدارة-الحاويات) · [استكشاف الأخطاء](#-استكشاف-الأخطاء)

</div>

---

## 📑 المحتويات

1. [نظرة عامة](#-نظرة-عامة)
2. [المتطلبات](#-المتطلبات)
3. [معلومات الدخول والمنافذ](#-معلومات-الدخول-والمنافذ)
4. [التثبيت السريع](#-التثبيت-السريع)
5. [تشغيل أكثر من نسخة](#-تشغيل-أكثر-من-نسخة)
6. [الإعدادات](#️-الإعدادات)
7. [إدارة الحاويات](#-إدارة-الحاويات)
8. [النسخ الاحتياطي](#-النسخ-الاحتياطي)
9. [الصلاحيات وإعداد Linux](#️-الصلاحيات-وإعداد-linux)
10. [Traefik وHTTPS](#-traefik-وhttps-اختياري)
11. [استكشاف الأخطاء](#-استكشاف-الأخطاء)
12. [هيكل المشروع والأمان](#-هيكل-المشروع-والأمان)
13. [روابط مفيدة](#-روابط-مفيدة)

---

## 🔎 نظرة عامة

يشغّل المشروع Odoo 20 وقاعدة PostgreSQL 18 داخل حاويات Docker. تبقى قاعدة
البيانات على شبكة داخلية ولا يُنشر منفذها على الإنترنت.

```mermaid
flowchart LR
    U([المستخدم]) -->|HTTP :10020| O[Odoo 20]
    U -->|خدمة المحادثة :20020| O
    O -->|شبكة Docker داخلية| D[(PostgreSQL 18)]
    D --> P[(مجلد postgresql)]
    O --> F[(حجم بيانات Odoo)]
```

| الخدمة | الصورة | منافذ المضيف الافتراضية | حفظ البيانات |
|---|---|---|---|
| Odoo | `odoo:20` | `10020` للويب، `20020` للمحادثة | حجم Docker باسم `odoo_data` |
| PostgreSQL | `postgres:18` | غير مكشوف للمضيف | المجلد `postgresql/` |

---

## ✅ المتطلبات

- Ubuntu 22.04/24.04 أو توزيعة Linux مناسبة.
- Docker Engine.
- Docker Compose v2، ويُستخدم بالأمر `docker compose`.
- اتصال بالإنترنت عند تنزيل الصور أول مرة.
- توفر المنفذين `10020` و`20020`، أو اختيار منافذ بديلة.

تحقق من توفر الأدوات:

```bash
docker --version
docker compose version
docker run --rm hello-world
```

> على Windows، نفّذ الأوامر عبر WSL 2 بعد تفعيل تكامل Docker مع WSL.

---

## 🔐 معلومات الدخول والمنافذ

| البيان | القيمة الافتراضية | الاستخدام |
|---|---|---|
| كلمة مرور Odoo الرئيسية | `Admin@20` | إدارة قواعد البيانات من واجهة Odoo |
| مستخدم PostgreSQL | `odoo20` | اتصال Odoo بقاعدة البيانات |
| كلمة مرور PostgreSQL | `odoo@20` | اتصال Odoo بقاعدة البيانات |
| قاعدة PostgreSQL الابتدائية | `postgre` | قاعدة تُنشأ عند تهيئة PostgreSQL لأول مرة |
| واجهة Odoo | `http://localhost:10020` | استخدام النظام من المتصفح |
| منفذ المحادثة المباشرة | `http://localhost:20020` | خدمة المحادثة والاتصال المباشر |

> كلمة مرور Odoo الرئيسية ليست كلمة مرور حساب المستخدم الذي ستنشئه داخل
> قاعدة بيانات Odoo. غيّر كلمات المرور الافتراضية قبل إتاحة الخادم للإنترنت.

---

## 🚀 التثبيت السريع

### 1. تنزيل المشروع

```bash
git clone https://github.com/abdalazeim/InstallingOdoo20-Docker-Deployment.git
cd InstallingOdoo20-Docker-Deployment
```

يمكن أيضًا تنزيل المستودع كملف ZIP وفك ضغطه، ثم فتح الطرفية داخل مجلد المشروع.

### 2. إعداد ملف البيئة والصلاحيات

```bash
cp .env.example .env
chmod 600 .env
sudo mkdir -p postgresql
sudo chmod 700 postgresql
chmod +x entrypoint.sh
```

> أنشئ `postgresql/` باستخدام `sudo`. تعمل حاوية PostgreSQL بالمستخدم `root`
> وتعيد كتابة ملكية المجلد؛ إذا كان المجلد مملوكًا لمستخدم تسجيل الدخول فقد
> تفشل الحاوية بـ `Permission denied`.

عدّل ملف `.env` وضع كلمات مرور قوية بدل القيم التجريبية قبل النشر العام.

### 3. تشغيل Odoo وPostgreSQL

```bash
docker compose pull
docker compose up -d
docker compose ps
```

افتح Odoo:

| الخدمة | الرابط |
|---|---|
| واجهة Odoo | [http://localhost:10020](http://localhost:10020) |
| منفذ المحادثة المباشرة | [http://localhost:20020](http://localhost:20020) |

> منفذ `20020` مخصص لخدمة المحادثة/الاتصال المباشر، وليس واجهة ويب مستقلة.

---

## 🧩 تشغيل أكثر من نسخة

ينسخ السكربت `run.sh` المستودع إلى **مجلد جديد**، ويضبط منافذ وأسماء حاويات
وشبكة خاصة بكل نسخة. لن يستبدل مجلدًا موجودًا.

```mermaid
flowchart TD
    A([بدء]) --> B{هل مجلد الوجهة موجود؟}
    B -->|نعم| X[توقف · اختر اسمًا آخر]
    B -->|لا| C{Git + Docker Compose متوفران؟}
    C -->|لا| Y[ثبّت المتطلبات]
    C -->|نعم| D[نسخ المستودع]
    D --> E[إنشاء .env ومجلد postgresql]
    E --> F[ضبط المنافذ والأسماء الفريدة]
    F --> G[تشغيل Odoo + PostgreSQL]
    G --> H([فتح رابط النسخة])
```

**المتطلبات:** Git وDocker وDocker Compose v2 وصلاحية تشغيل Docker.

نفّذ الأوامر من جذر المستودع:

```bash
# النسخة الأولى
sudo bash run.sh --destination odoo-live --port 10020 --chat 20020

# النسخة الثانية
sudo bash run.sh --destination odoo-test --port 11020 --chat 21020
```

| النسخة | المجلد | رابط Odoo | منفذ المحادثة |
|---|---|---|---|
| `odoo-live` | `odoo-live/` | [http://localhost:10020](http://localhost:10020) | `20020` |
| `odoo-test` | `odoo-test/` | [http://localhost:11020](http://localhost:11020) | `21020` |

لإدارة نسخة محددة، انتقل إلى مجلدها:

```bash
cd odoo-live
docker compose ps
docker compose logs -f
```

---

## ⚙️ الإعدادات

عدّل `.env` ولا تضفه إلى Git. الملف مستثنى بالفعل في `.gitignore`.

| المتغير | القيمة الافتراضية | الوظيفة |
|---|---|---|
| `ODOO_IMAGE` | `odoo:20` | صورة Odoo |
| `PG_IMAGE` | `postgres:18` | صورة PostgreSQL |
| `POSTGRES_USER` | `odoo20` | مستخدم قاعدة البيانات |
| `POSTGRES_PASSWORD` | `odoo@20` (غيّره فورًا) | كلمة مرور قاعدة البيانات |
| `POSTGRES_DB` | `postgre` | قاعدة تُنشأ عند تهيئة PostgreSQL لأول مرة |
| `ODOO_ADMIN_PASSWORD` | `Admin@20` | كلمة مرور Odoo الرئيسية |
| `ODOO_HTTP_PORT` | `10020` | منفذ المضيف لـ Odoo |
| `ODOO_CHAT_PORT` | `20020` | منفذ المضيف للمحادثة |
| `ODOO_DOMAIN` | مطلوب مع Traefik | اسم النطاق |
| `DOCKER_PROXY_NETWORK` | `proxy` | شبكة Traefik الخارجية |

> **قاعدة بيانات موجودة:** متغيرات تهيئة PostgreSQL تُطبَّق عند أول تهيئة
> لمجلد البيانات فقط. تغيير كلمات المرور في `.env` لا يغيّر بيانات PostgreSQL
> الموجودة.

الإضافات المخصصة توضع في `addons/`. إعداد Odoo الأساسي موجود في
`etc/odoo.conf`، بينما تُحقن الأسرار وقت التشغيل من البيئة.

---

## 🧰 إدارة الحاويات

نفّذ الأوامر من مجلد النشر:

| العملية | الأمر |
|---|---|
| تشغيل | `docker compose up -d` |
| حالة الحاويات | `docker compose ps` |
| سجلات كل الخدمات | `docker compose logs -f` |
| سجلات Odoo | `docker compose logs -f odoo20` |
| سجلات PostgreSQL | `docker compose logs -f db` |
| إعادة تشغيل | `docker compose restart` |
| إيقاف مع إبقاء الحاويات والبيانات | `docker compose stop` |
| إيقاف مع الحفاظ على البيانات | `docker compose down` |

الخدمتان تستخدمان `restart: always`. يحفظ `docker compose down` البيانات.
تجنب `docker compose down -v` إلا إذا كنت تريد حذف حجم بيانات Odoo. لا تحذف
مجلد `postgresql/` إلا إذا كنت تريد حذف بيانات قاعدة البيانات.

---

## 💾 النسخ الاحتياطي

البيانات محفوظة في مجلد `postgresql/` وحجم Odoo المسمى `odoo_data`. نفّذ
الأوامر التالية من مجلد النسخة الافتراضية؛ إذا أنشأت النسخة عبر `run.sh`
فاستخدم أسماء الحاويات التي تظهرها `docker compose ps`.

```bash
mkdir -p backups
docker exec odoo20-db pg_dumpall -U odoo20 > backups/postgresql-all.sql
docker exec odoo20 tar -C /var/lib/odoo -czf /tmp/odoo-data.tar.gz .
docker cp odoo20:/tmp/odoo-data.tar.gz backups/odoo-data.tar.gz
docker exec odoo20 rm -f /tmp/odoo-data.tar.gz
```

احمِ ملفات النسخ الاحتياطي، واحتفظ بنسخة إضافية خارج الخادم، واختبر
الاستعادة دوريًا.

---

## 🔒 الصلاحيات وإعداد Linux

### الصلاحيات

لا تستخدم `chmod -R 777`؛ فهو يمنح صلاحيات كاملة لكل مستخدم على النظام. استخدم
صلاحيات محدودة:

```bash
chmod 600 .env
chmod 700 postgresql
chmod +x entrypoint.sh
```

إذا ظهر خطأ صلاحيات لمسار mount محدد، افحص السجلات والمسار أولًا:

```bash
docker compose logs --tail=100
ls -ld addons etc postgresql
```

عدّل صلاحيات المجلد المتأثر فقط. لا تجعل ملفات قاعدة البيانات أو الأسرار قابلة
للكتابة للجميع.

### اختياري · رفع حد inotify

قد يفيد هذا الإعداد عند تشغيل عدة نسخ ويظهر حد مراقبة الملفات في Linux:

```bash
if grep -qF "fs.inotify.max_user_watches" /etc/sysctl.conf; then
  grep -F "fs.inotify.max_user_watches" /etc/sysctl.conf
else
  echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf
fi

sudo sysctl -p
```

---

## 🌐 Traefik وHTTPS (اختياري)

استخدم [`docker-compose.traefik.yml`](docker-compose.traefik.yml) فقط إذا كان
Traefik يعمل بالفعل والشبكة الخارجية موجودة.

```dotenv
ODOO_DOMAIN=odoo.example.com
DOCKER_PROXY_NETWORK=proxy
CERTSRESOLVER=letsencrypt
```

```bash
docker network create proxy   # إذا لم تكن الشبكة موجودة
docker compose -f docker-compose.traefik.yml up -d
```

اضبط DNS وإعدادات Traefik على الخادم، ثم افتح `https://odoo.example.com`. لا
تشغّل وضع المنافذ المباشرة ووضع Traefik للنسخة نفسها في الوقت نفسه.

---

## 🩺 استكشاف الأخطاء

| المشكلة | الإجراء |
|---|---|
| المنفذ مستخدم | غيّر `ODOO_HTTP_PORT` أو `ODOO_CHAT_PORT` في `.env` ثم نفّذ `docker compose up -d` |
| Odoo لا يتصل بقاعدة البيانات | راجع `docker compose logs db odoo20` |
| فحص جاهزية PostgreSQL | نفّذ `docker compose exec db pg_isready -U odoo20 -d postgre` |
| خطأ في إعداد Odoo | راجع `docker compose logs --tail=100 odoo20` |
| كلمات المرور تغيّرت دون أثر | بيانات PostgreSQL الحالية لا تُعاد تهيئتها من `.env` |
| `PostgreSQL data in /var/lib/postgresql/data (unused mount/volume)` أو `mkdir: cannot create directory '/var/lib/postgresql': Permission denied` | صور PostgreSQL 18 تخزّن البيانات في مجلد يحمل رقم الإصدار. يجب أن يكون التركيب `./postgresql:/var/lib/postgresql` مع `PGDATA=/var/lib/postgresql/18/docker`، وأن تعمل خدمة `db` بالمستخدم `root` ليصحح entrypoint الملكية |
| Traefik لا يوجّه الطلب | تحقق من DNS والشبكة الخارجية و`ODOO_DOMAIN` |

```mermaid
flowchart LR
    A([Odoo لا يعمل]) --> B{هل الحاويات تعمل؟}
    B -->|لا| C[افحص docker compose ps]
    B -->|نعم| D{هل قاعدة البيانات جاهزة؟}
    D -->|لا| E[افحص سجلات PostgreSQL وكلمات المرور]
    D -->|نعم| F{هل المنفذ صحيح؟}
    F -->|لا| G[راجع المنافذ في .env]
    F -->|نعم| H[افحص سجلات Odoo والإعدادات]
```

---

## 🗂️ هيكل المشروع والأمان

```text
InstallingOdoo20-Docker-Deployment/
├── addons/                       # الإضافات المخصصة
├── etc/
│   ├── odoo.conf                 # قالب إعداد Odoo
│   └── requirements.txt          # حزم Python اختيارية
├── postgresql/                   # بيانات PostgreSQL (دائمة)
├── .env.example                  # قالب متغيرات البيئة
├── docker-compose.yml            # نشر مباشر عبر منافذ المضيف
├── docker-compose.traefik.yml    # نشر اختياري عبر Traefik
├── entrypoint.sh                 # تهيئة الإعداد وانتظار PostgreSQL
├── run.sh                        # تثبيت اختياري لنسخ متعددة
└── README.md
```

**قائمة أمان سريعة:**

- غيّر كلمات مرور Odoo وPostgreSQL الافتراضية.
- لا ترفع `.env` أو بيانات قواعد البيانات أو النسخ الاحتياطية إلى Git.
- لا تنشر منفذ PostgreSQL.
- استخدم HTTPS عبر وكيل عكسي موثوق عند النشر العام.
- حدّث صور Docker وخادم المضيف بانتظام.

---

## 🔗 روابط مفيدة

- [توثيق Odoo 20](https://www.odoo.com/documentation/20.0/)
- [توثيق Docker Compose](https://docs.docker.com/compose/)
- [مستودع GitHub](https://github.com/abdalazeim/InstallingOdoo20-Docker-Deployment)
- [الإبلاغ عن مشكلة](https://github.com/abdalazeim/InstallingOdoo20-Docker-Deployment/issues)

<div dir="rtl" align="right">

Odoo 20 · PostgreSQL 18 · Docker Compose · Ubuntu/Linux · Traefik (اختياري)

</div>
