# NYC Krungthai Campus Registration V4

ระบบลงทะเบียนข้อมูลผู้ใช้สำหรับเตรียมทะเบียน Krungthai Campus ของวิทยาลัยการอาชีพนครยะลา — **ไม่ใช่แอปของธนาคาร** และไม่ใช่ระบบสำรวจ V3 เดิม

## สถาปัตยกรรม

- `site/` Frontend สำหรับ GitHub Pages: ฟอร์มลงทะเบียน + Admin (ไม่เก็บข้อมูลผู้ใช้ใน repository)
- `worker/` Cloudflare Worker API Gateway: CORS Origin, HMAC Admin token อายุ 90 นาที, ตรวจ SHA-256 password hash
- `apps-script/` Google Apps Script Web App ที่ผูกกับ Google Sheet ใช้ `getSharedSecret_()` ในไฟล์ Config.gs ซึ่งสร้างเฉพาะที่เครื่องติดตั้งเท่านั้น
- Google Sheets: `Users_A_W` (23 คอลัมน์ตามแม่แบบธนาคาร), `RegistrationExtra`, `Options`, `Settings`, `EmailOTP`, `Audit`

## ฟอร์ม

- STUDENT: รหัสนักเรียน/นักศึกษา B, บัตรประชาชน U หรือ Passport V, ข้อมูลระดับ O, ชั้นปี P, ระดับปัจจุบันและสาขาวิชาเก็บใน RegistrationExtra
- TEACHER/STAFF: ใช้บัตรประชาชนหรือพาสปอร์ตเป็นเลขประจำตัว B, O=OTHER และ P=0 อัตโนมัติ ไม่แสดงส่วนการศึกษา
- A = B เป็นค่าเริ่มต้นเพื่อให้มี ID อ้างอิงที่ไม่ซ้ำ; Admin แก้ไขให้ตรงข้อตกลงธนาคารภายหลังได้ผ่านช่อง B/ข้อมูลต้นฉบับ (A คงเป็นรหัสอ้างอิง) **โปรดยืนยันกับธนาคารว่าใช้ A=B ได้จริง**
- C=1 (ตามข้อกำหนดของผู้ใช้) ไม่แสดง; W=Active ไม่แสดง; E/F ชื่อคำนำหน้าไทย/อังกฤษ
- หน้าเลือกวันเดือนปี พ.ศ. ส่ง K เป็น ค.ศ. yyyy-mm-dd
- OTP ไปยังอีเมล (10 นาที, สูงสุด 3 ครั้งต่อวัน/อีเมล, 5 ครั้งทดลอง)
- Q ต้องเป็นรหัสคณะซึ่งได้รับจากธนาคาร; Admin ตั้งค่า defaultFacultyId หรือค่าผูกในตัวเลือกสาขาวิชา ส่วน R/S ตั้งค่าในตัวเลือกสาขาวิชาได้
- คำตอบยินยอมส่งธนาคารต้องแยกจากการรับทราบประกาศ การดาวน์โหลดไฟล์เพียงเพื่อเตรียมข้อมูล ไม่ได้ส่งธนาคารอัตโนมัติ

## ตัวเลือกที่แก้ได้ใน Admin

`prefix`, `gender`, `role`, `degree`, `studyYear`, `currentLevel`, `department`, `nationality`: เพิ่ม/แก้ชื่อไทย อังกฤษ รหัส สถานะใช้งาน ลำดับ กลุ่ม และรหัส Q/R/S ได้

รหัส Degree ค่าเริ่มต้นตามที่ผู้ใช้ยืนยัน:

`BACHELOR`, `MASTER`, `DOCTORAL`, `OTHER`, `DIPLOMA`, `CERTIFICATE`, `HIGH_SCHOOL`, `ELEMENTARY`, `KINDERGARTEN`, `HONORARY`, `MIDDLE_SCHOOL`, `ASSOCIATE_DEGREE`

**ข้อควรทราบ:** ผู้ดูแลสามารถเพิ่มตัวเลือกระดับการศึกษาได้ แต่ถ้ารหัสใหม่ไม่อยู่ในชุดที่ธนาคารกำหนด ระบบตรวจสอบการส่งออกจะปฏิเสธเพื่อป้องกันไฟล์ที่ธนาคารไม่รองรับ

## ติดตั้ง (Windows Git Bash)

1. แตก ZIP เปิดโฟลเดอร์ที่มี `install.sh`
2. ต้องมี `node`, `npm`, `gh`, `clasp` และ `npx wrangler`; ลงชื่อเข้าใช้ `gh auth login`, `clasp login`, `npx wrangler login`
3. เปิด Google Apps Script API ที่ https://script.google.com/home/usersettings
4. เรียก `bash install.sh`; ตัวติดตั้งจะสร้าง **Google Sheet/Apps Script ใหม่, Worker ใหม่, GitHub repo ใหม่** แยกจาก V3
5. Deploy Apps Script → New deployment → Web app → Execute as Me → Anyone → Authorize → วาง `/exec` URL (ห้ามใช้ Library URL)
6. ตัวติดตั้งจะตรวจ backend ping, Worker health/config, push ไฟล์ GitHub และพยายามเปิด Pages
7. เข้าหน้า Admin ด้วยรหัสผ่านที่ตั้งเอง แล้วกำหนด Privacy Notice, รหัสคณะ Q, ตัวเลือกสาขาวิชา และเปิดรับลงทะเบียน

### GitHub Repository

ตัวติดตั้งสร้าง Repository **Public** สำหรับ GitHub Pages โดยเก็บเฉพาะโค้ดสาธารณะ (ไม่มีข้อมูลผู้ลงทะเบียนจริง) โฟลเดอร์ `private/`, `.local/` และไฟล์ Excel/CSV ถูกละเว้นด้วย `.gitignore` และคำสั่ง Git จะเพิ่มเฉพาะรายการที่ระบุไว้เท่านั้น การตรวจว่าไม่มีข้อมูลอ่อนไหวก่อน push ยังคงสำคัญ

### ความปลอดภัยที่ยังต้องเตรียมก่อนเปิดใช้กับข้อมูลจริง

- กำหนดผู้ควบคุมข้อมูลส่วนบุคคล ผู้มีสิทธิ์เข้าถึง และมาตรการแจ้งเหตุข้อมูลรั่วไหล/ลบข้อมูลตาม PDPA
- เปิด Cloudflare WAF / Rate Limiting หรือ Turnstile เพื่อป้องกันผู้ไม่ประสงค์ดีเรียก OTP จำนวนมาก; โควตา OTP ต่ออีเมลไม่ป้องกันการยิงหลายอีเมล
- Google Apps Script Web App แบบ Anyone รับคำขอจากอินเทอร์เน็ตได้ แต่ตรวจ shared secret ก่อนทำงาน ให้เก็บ Secret ในบัญชี Google/Cloudflare อย่างจำกัดสิทธิ์
- ตรวจข้อกำหนดของธนาคารเรื่องแผนรหัส A/Q/R/S, C=1, O/P ของครู และการใช้ข้อมูลความยินยอม ก่อนส่งไฟล์จริง
- ทำสำรองข้อมูล จัดการผู้ดูแลหลายคน/สิทธิ์ และกำหนดอายุข้อมูลก่อนใช้งานกับข้อมูลนักเรียนจริง
- ส่งอีเมล OTP ใช้ Google MailApp ภายใต้ quota ของบัญชีเจ้าของสคริปต์ ไม่ใช่อีเมลโดเมนวิทยาลัยอัตโนมัติ
- อย่าส่งภาพหน้าจอที่เผยเลขบัตรประชาชน วันเกิด ข้อมูลบัญชี หรือไฟล์ secret มาในแชต

## ข้อจำกัดที่ทดสอบแล้วและยังไม่ได้ทดสอบ

- ตรวจไวยากรณ์ frontend/Worker และ Apps Script; ทดสอบแบบจำลองบางส่วนได้
- ต้องทดสอบจริงอีกครั้ง: Deploy OAuth/MailApp, OTP delivery, บันทึกกับ Google Sheets, ค่า A–W และ Bank Export ผ่าน Browser ก่อนเปิดรับข้อมูลบุคคลจริง
- หากระบบเดิม V3 ตั้งค่ารหัสผิด ให้แยกไว้ ไม่ควร migrate Secrets/ไฟล์ฐานข้อมูลเดิมโดยอัตโนมัติ
