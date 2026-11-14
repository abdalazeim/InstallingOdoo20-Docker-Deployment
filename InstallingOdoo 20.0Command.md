<div dir="rtl" align="right">

# دليل تثبيت Odoo 20 باستخدام Docker Compose

**Odoo 20 · PostgreSQL 18 · Docker Compose · Traefik اختياري**

دليل عملي لتثبيت Odoo 20 وتشغيل أكثر من نسخة على الخادم نفسه، مبني على
تجربة تثبيت فعلية على Ubuntu.

[التثبيت السريع](#-التثبيت-السريع) · [أكثر من نسخة](#-تشغيل-أكثر-من-نسخة) ·
[الإعدادات](#️-الإعدادات) · [إدارة الحاويات](#-إدارة-الحاويات) ·
[النسخ الاحتياطي](#-النسخ-الاحتياطي) · [استكشاف الأخطاء](#-استكشاف-الأخطاء)

</div>

---

## ‏🔎 نظرة عامة

يشغّل المشروع Odoo 20 و PostgreSQL 18 داخل حاويات Docker. قاعدة البيانات على
شبكة داخلية معزولة ولا يُنشر منفذها على المضيف.

| الخدمة | الصورة | منفذ المضيف | تخزين البيانات |
|---|---|---|---|
| Odoo | `odoo:20` | `10020` ويب · `20020` محادثة | حجم `odoo_data` |
| PostgreSQL | `postgres:18` | غير منشور | حجم `odoo_pgdata` |

> **PostgreSQL 18** يغيّر مكان البيانات إلى `/var/lib/postgresql/18/docker`.
> لذلك لا يعمل التركيب القديم على `/var/lib/postgresql/data`. المشروع يستخدم
> حجمًا مُدارًا من Docker (`odoo_pgdata`) لتفادي مشاكل ملكية المجلدات على
> المضيف نهائيًا.

---

## ‏✅ المتطلبات

- Ubuntu 22.04/24.04 أو توزيعة Linux مناسبة.
- Docker Engine و Docker Compose v2 (الأمر `docker compose`).
- صلاحية تشغيل Docker (عضوية مجموعة `docker` أو `sudo`).
- منافذ `10020` و`20020` متاحة، أو منافذ بديلة.

```bash
docker --version
docker compose version
docker run --rm hello-world
```

---

## ‏🔐 معلومات الدخول والمنافذ

| البيان | القيمة الافتراضية | الاستخدام |
|---|---|---|
| كلمة مرور Odoo الرئيسية | `Admin@20` | عمليات إدارة قواعد البيانات |
| مستخدم PostgreSQL | `odoo20` | اتصال Odoo بقاعدة البيانات |
| كلمة مرور PostgreSQL | `odoo@20` | اتصال Odoo بقاعدة البيانات |
| قاعدة PostgreSQL الابتدائية | `postgre` | قاعدة تُنشأ عند أول تهيئة فقط |
| قاعدة Odoo | `odoo10020` | قاعدة Odoo التي يهيئها `run.sh` |
| واجهة Odoo | `http://localhost:10020/odoo` | الاستخدام من المتصفح |
| منفذ المحادثة | `http://localhost:20020` | خدمة المحادثة اللحظية (غير قابلة للتصفح) |

> `POSTGRES_DB` في `.env` هي قاعدة تهيئة PostgreSQL فقط، وليست قاعدة Odoo.
> غيّر كل كلمات المرور الافتراضية قبل النشر العام.

---

## ‏🚀 التثبيت السريع

### 1. تنزيل المشروع

```bash
git clone https://github.com/abdalazeim/InstallingOdoo20-Docker-Deployment.git
cd InstallingOdoo20-Docker-Deployment
```

### 2. إعداد ملف البيئة

```bash
cp .env.example .env
chmod 600 .env
chmod +x entrypoint.sh
```

عدّل `.env` وضع كلمات مرور قوية. لا ترفع `.env` إلى Git.

### 3. التشغيل

```bash
docker compose pull
docker compose up -d
docker compose ps
```

### 4. تهيئة قاعدة بيانات Odoo

قاعدة `postgre` التي تنشئها صورة PostgreSQL **غير مهيأة** لـ Odoo، لذا
صفحة الدخول تعيد `500` (أو تحوّل إلى `/web/database/selector`) حتى تُهيّأ قاعدة
Odoo. أوقف Odoo لتحرير المنفذ، ثم هيّئ القاعدة، ثم أعد التشغيل:

```bash
docker compose stop odoo20
docker compose run --rm --no-deps odoo20 -c /tmp/odoo.conf -d odoo20 \
  -i base --stop-after-init
docker compose start odoo20
```

لا تُضِف `--entrypoint odoo`؛ فـ entrypoint هو من يولّد `/tmp/odoo.conf`،
وتجاوزه يعطي `config file '/tmp/odoo.conf' ... doesn't exist`. ولا تستخدم
`--without-demo=all`؛ فـ Odoo 20 يرفضها.

### 5. التحقق

```bash
curl -I http://localhost:10020/odoo
```

مع ضبط `ODOO_DB_NAME` (بالأسفل) يكون الرد إعادة توجيه إلى صفحة الدخول أو
`200`، وليس `/web/database/selector` أبدًا. ثم افتح
`http://<IP>:10020/odoo` في المتصفح.

> **بادئة Odoo 20:** انتقلت واجهة الويب من `/web` إلى `/odoo`.
> `http://الخادم:10020/` يعيد التوجيه إلى `/odoo`، و`/odoo/discuss` و
> `/odoo/sales` هي نقاط الدخول الطبيعية. المسارات `/web/login` و
> `/web/database/manager` و`/web/database/selector` ما زالت موجودة كمسارات
> خلفية قديمة. هذا سلوك Odoo المتعمد وليس خللًا في التثبيت.

> **`ODOO_DB_NAME` لازمة لجلسة متصفح عاملة.** مع `list_db = False` لا يستطيع
> Odoo عرض منتقي قواعد البيانات، لذا غياب `ODOO_DB_NAME` يُبقي `/odoo` عند
> `303 -> /web/database/selector`. اضبطه على اسم القاعدة الذي أُنشئ في الخطوة 4
> (الافتراضي `odoo20`) ثم أعد إنشاء الحاوية:
> `docker compose up -d --force-recreate odoo20`.

---

## ‏🧩 تشغيل أكثر من نسخة

ينسخ `run.sh` المستودع إلى **مجلد جديد**، ويضبط منافذ وأسماء حاويات وشبكة
خاصة بكل نسخة، ثم ينتظر جاهزية PostgreSQL و Odoo ويهيئ قاعدة Odoo تلقائيًا.
لن يستبدل مجلدًا موجودًا.

```bash
# النسخة الأولى
sudo bash run.sh --destination odoo-live --port 10020 --chat 20020

# النسخة الثانية
sudo bash run.sh --destination odoo-test --port 11020 --chat 21020 --db odoo_test
```

| الخيار | الوظيفة |
|---|---|
| `--destination` | مجلد النسخة (إلزامي) |
| `--port` | منفذ Odoo على المضيف (إلزامي) |
| `--chat` | منفذ المحادثة (إلزامي) |
| `--db` | اسم قاعدة Odoo (افتراضي `odoo<port>`) |
| `--skip-init` | تشغيل الحاويات دون تهيئة قاعدة Odoo |

الروابط بعد التثبيت:

| النسخة | المجلد | رابط Odoo | منفذ المحادثة |
|---|---|---|---|
| `odoo-live` | `odoo-live/` | `http://localhost:10020/odoo` | `20020` |
| `odoo-test` | `odoo-test/` | `http://localhost:11020/odoo` | `21020` |

لإدارة نسخة معينة:

```bash
cd odoo-live
docker compose ps
docker compose logs -f
```

---

## ‏⚙️ الإعدادات

| المتغير | القيمة الافتراضية | الوظيفة |
|---|---|---|
| `ODOO_IMAGE` | `odoo:20` | صورة Odoo |
| `PG_IMAGE` | `postgres:18` | صورة PostgreSQL |
| `POSTGRES_USER` | `odoo20` | دور قاعدة البيانات |
| `POSTGRES_PASSWORD` | `odoo@20` | كلمة مرور قاعدة البيانات |
| `POSTGRES_DB` | `postgre` | قاعدة تهيئة PostgreSQL فقط |
| `ODOO_ADMIN_PASSWORD` | `Admin@20` | كلمة مرور Odoo الرئيسية |
| `ODOO_DB_NAME` | `odoo20` | قاعدة Odoo التي تخدمها هذه النسخة (`db_name`)؛ اتركها فارغة لوضع منتقي القواعد |
| `ODOO_HTTP_PORT` | `10020` | منفذ المضيف لـ Odoo |
| `ODOO_CHAT_PORT` | `20020` | منفذ المضيف للمحادثة |
| `ODOO_NETWORK` | `odoo20_internal` | الشبكة الداخلية |
| `ODOO_CONTAINER_NAME` | `odoo20` | اسم حاوية Odoo |
| `ODOO_DB_CONTAINER_NAME` | `odoo20-db` | اسم حاوية PostgreSQL |
| `ODOO_DOMAIN` | مطلوب مع Traefik | اسم النطاق |
| `DOCKER_PROXY_NETWORK` | `proxy` | شبكة Traefik الخارجية |

> **قاعدة بيانات موجودة:** متغيرات PostgreSQL تُطبَّق عند أول تهيئة فقط.
> تغيير كلمات المرور في `.env` لا يغيّر بيانات موجودة.

الإضافات في `addons/`، وإعداد Odoo في `etc/odoo.conf` (يُحقن منه
`/tmp/odoo.conf` وقت التشغيل).

### تخزين بيانات PostgreSQL على المضيف (اختياري)

الملف `docker-compose.bindmount.yml` يضع البيانات في `./postgresql` بدل الحجم
المُدار:

```bash
sudo rm -rf postgresql
sudo mkdir -p postgresql
sudo chmod 700 postgresql
docker compose -f docker-compose.bindmount.yml up -d
```

> يجب إنشاء المجلد بـ `sudo`. إذا كان مملوكًا لمستخدم آخر فقد تفشل الحاوية بـ
> `mkdir: cannot create directory '/var/lib/postgresql': Permission denied`.

---

## ‏🧰 إدارة الحاويات

| العملية | الأمر |
|---|---|
| تشغيل | `docker compose up -d` |
| الحالة | `docker compose ps` |
| السجلات | `docker compose logs -f` |
| سجلات Odoo | `docker compose logs -f odoo20` |
| سجلات PostgreSQL | `docker compose logs -f db` |
| إعادة تشغيل | `docker compose restart` |
| إيقاف مع حفظ البيانات | `docker compose down` |

كل الخدمات تستخدم `restart: always`. تجنب `docker compose down -v` لأنه يحذف
حجم قاعدة البيانات.

---

## ‏💾 النسخ الاحتياطي

```bash
mkdir -p backups
docker exec odoo20-db pg_dumpall -U odoo20 > backups/postgresql-all.sql
docker exec odoo20 tar -C /var/lib/odoo -czf /tmp/odoo-data.tar.gz .
docker cp odoo20:/tmp/odoo-data.tar.gz backups/odoo-data.tar.gz
docker exec odoo20 rm -f /tmp/odoo-data.tar.gz
```

استخدم أسماء الحاويات الظاهرة في `docker compose ps` عند العمل مع نسخة من
`run.sh`. احمِ ملفات النسخ، واحتفظ بنسخة خارج الخادم، واختبر الاستعادة دوريًا.

---

## ‏🌐 Traefik و HTTPS (اختياري)

استخدم `docker-compose.traefik.yml` فقط إذا كان Traefik يعمل وشبكته موجودة.

```dotenv
ODOO_DOMAIN=odoo.example.com
DOCKER_PROXY_NETWORK=proxy
CERTSRESOLVER=letsencrypt
```

```bash
docker network create proxy   # إن لم تكن موجودة
docker compose -f docker-compose.traefik.yml up -d
```

لا تشغّل وضع المنافذ المباشرة ووضع Traefik للنسخة نفسها في الوقت نفسه.

---

## ‏🩺 استكشاف الأخطاء

| المشكلة | الإجراء |
|---|---|
| المنفذ مستخدم | غيّر `ODOO_HTTP_PORT` أو `ODOO_CHAT_PORT` في `.env` ثم `docker compose up -d` |
| Odoo لا يتصل بقاعدة البيانات | `docker compose logs db odoo20` |
| فحص جاهزية PostgreSQL | `docker compose exec db pg_isready -U odoo20 -d postgre` |
| `curl` يعيد الاتصال والسجل يقول `HTTP service running on 127.0.0.1:8069` | أضف `http_interface = 0.0.0.0` إلى `etc/odoo.conf` ثم أعد التشغيل |
| `500` على صفحة الدخول مع `Database <db> not initialized` | نفّذ `odoo -c /tmp/odoo.conf -d <db> -i base --stop-after-init` |
| `303 -> /web/database/selector` على كل الروابط | `ODOO_DB_NAME` فارغ أو لا يطابق قاعدة مهيأة. اضبطه في `.env` ثم `docker compose up -d --force-recreate odoo20` |
| `exec: "/entrypoint.sh": permission denied` | أعد إنشاء الحاوية؛ ملفات compose تشغّل entrypoint عبر `["/bin/sh", "/entrypoint.sh"]` |
| `Unknown command 'odoo'` من `docker compose run` | لا تُمرّر أمرًا يبدأ بـ `odoo`؛ الـ entrypoint يضيفه تلقائيًا |
| `/` يعيد التوجيه و`/odoo/...` يعمل | سلوك Odoo 20 الطبيعي: انتقلت الواجهة من `/web` إلى `/odoo`. افتح `http://الخادم:10020/odoo` |
| `http://الخادم:20020/` لا يعرض شيئًا | المنفذ `20020` لخدمة WebSocket فقط وليس واجهة ويب. استخدم `10020` |
| `mkdir: cannot create directory '/var/lib/postgresql'` | احذف `postgresql/` بـ `sudo` وأنشئه بـ `sudo` (أو استخدم الحجم المُدار) |
| `PostgreSQL data in /var/lib/postgresql/data (unused mount/volume)` | استخدم `PGDATA=/var/lib/postgresql/18/docker` والتركيب على `/var/lib/postgresql` |
| `Address already in use` أثناء التهيئة | الحاوية تعمل بالفعل؛ لا تشغّل `odoo` يدويًا داخلها. أعد التشغيل فقط |
| خطأ عميل `odoo.loader.modules.get(...) is undefined` | امسح ذاكرة أصول المتصفح (hard reload)، ثم أعد بناء الأصول: `docker compose run --rm --no-deps odoo20 -c /tmp/odoo.conf -d <db> --stop-after-init` |
| `sed: couldn't open temporary file ... Permission denied` | ملفات المجلد مملوكة لـ root. نفّذ `sudo chown -R "$USER":"$USER" <المجلد>` ثم عدّل بدون `sudo` |
| كلمات المرور تغيّرت بلا أثر | بيانات PostgreSQL الحالية لا تُعاد تهيئتها من `.env` |

---

## ‏🗂️ هيكل المشروع والأمان

```text
InstallingOdoo20-Docker-Deployment/
├── addons/                          # إضافات Odoo المخصصة
├── etc/
│   ├── odoo.conf                    # قالب إعداد Odoo
│   └── requirements.txt             # حزم Python اختيارية
├── postgresql/                      # بيانات PostgreSQL (bind mount اختياري)
├── .env.example                     # قالب متغيرات البيئة
├── docker-compose.yml               # نشر مباشر (حجم مُدار)
├── docker-compose.bindmount.yml     # نشر مباشر (مجلد مضيف)
├── docker-compose.traefik.yml       # نشر عبر Traefik
├── entrypoint.sh                    # إعداد وقت التشغيل وانتظار PostgreSQL
├── run.sh                           # مثبّت النسخ المتعددة
└── README.md
```

**قائمة أمان سريعة:**

- غيّر كلمات مرور Odoo و PostgreSQL الافتراضية.
- لا ترفع `.env` أو بيانات قواعد البيانات أو النسخ الاحتياطية إلى Git.
- لا تنشر منفذ PostgreSQL.
- استخدم HTTPS عبر وكيل عكسي موثوق عند النشر العام.
- حدّث صور Docker والخادم بانتظام.

---

## ‏🔗 روابط مفيدة

- [توثيق Odoo 20](https://www.odoo.com/documentation/20.0/)
- [توثيق Docker Compose](https://docs.docker.com/compose/)
- [ملاحظة PGDATA في صور PostgreSQL](https://github.com/docker-library/postgres/pull/1259)
- [مستودع GitHub](https://github.com/abdalazeim/InstallingOdoo20-Docker-Deployment)