import json, mimetypes
from pathlib import Path
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]

opts=[]
for c,values in {
 'role':[('STUDENT','นักเรียน','student'),('TEACHER','ครู','staff')],
 'prefix':[('MISS','นางสาว','all')],
 'gender':[('FEMALE','หญิง','all')],
 'degree':[('DIPLOMA','ปวส.','student')],
 'studyYear':[('1','ปี 1','student')],
 'currentLevel':[('ปวส.','ปวส.','student')],
 'department':[('DIGITAL_BUSINESS','สาขาธุรกิจดิจิทัล','student')],
 'nationality':[('THAI','ไทย','all')]
}.items():
 for code, label, audience in values:opts.append(dict(category=c,code=code,labelTh=label,labelEn='',audience=audience,enabled=True))
config={'ok':True,'config':{'registrationOpen':True,'privacyNotice':'ข้อมูลทดสอบ ไม่ใช่ข้อมูลจริง','privacyContact':'ฝ่ายทดสอบ','options':opts}}
passed=[]
def render(page,name,js):
 import re
 html=(root/'site'/name).read_text()
 html=re.sub(r'<script[^>]+src="[^"]+"[^>]*></script>','',html)
 html=re.sub(r'<link[^>]+(?:rel="stylesheet"|rel="preconnect")[^>]*>','',html)
 page.set_content(html,wait_until='domcontentloaded')
 page.add_style_tag(content=(root/'site'/'style.css').read_text())
 page.evaluate("window.NYC_API_URL='https://mock.test'")
 if name=='index.html':page.evaluate('window.TEST_CONFIG='+json.dumps(config,ensure_ascii=False))
 else:page.evaluate("window.TEST_ADMIN=async(url)=>String(url).endsWith('/login')?new Response(JSON.stringify({ok:true,token:'MOCK'}),{status:200}):new Response(JSON.stringify({ok:false,error:'Mock stats unavailable'}),{status:502}); undefined")
 page.evaluate("window.fetch = async function(url,opts){ if(String(url).includes('/api/config')) return new Response(JSON.stringify(window.TEST_CONFIG),{status:200}); if(String(url).includes('/api/otp/request')) return new Response(JSON.stringify({ok:true,retryAfter:90,expiresIn:600,message:'Mock OTP sent'}),{status:200}); if(String(url).includes('/api/register')) return window.TEST_REGISTER(url,opts); if(String(url).includes('/api/admin/')) return window.TEST_ADMIN(url,opts); return new Response('{}',{status:404});}")
 page.add_script_tag(content=(root/'site'/js).read_text())
try:
 with sync_playwright() as pw:
  browser=pw.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage'],headless=True)
  for width in [360,768,1280]:
   print('BEGIN',width,flush=True)
   page=browser.new_page(viewport={'width':width,'height':900},device_scale_factor=1);page.set_default_timeout(3000)
   errors=[]
   page.on('pageerror',lambda e:errors.append(str(e)))
   render(page,'index.html','app.js');print('RENDERED',flush=True)
   page.wait_for_function("document.querySelector('#open-state').textContent.includes('เปิดรับ')",timeout=3000);print('LOADED',flush=True)
   overflow=page.evaluate('document.documentElement.scrollWidth > document.documentElement.clientWidth')
   assert not overflow,(width,page.evaluate('document.documentElement.scrollWidth'))
   assert not errors,errors
   passed.append(f'{width}px viewport: no horizontal overflow, form loads')
   if width==360:
    page.locator('#role').select_option('STUDENT');page.locator('#identity').fill('00010001')
    page.locator('#prefix').select_option('MISS');page.locator('#gender').select_option('FEMALE')
    for id,val in [('firstTh','ทดสอบ'),('lastTh','ตัวอย่าง'),('firstEn','Test'),('lastEn','Example')]:page.locator(f'[name={id}]').fill(val)
    page.locator('#day').select_option('1');page.locator('#month').select_option('1');page.locator('#year').select_option('2550')
    for id,val in [('degree','DIPLOMA'),('studyYear','1'),('currentLevel','ปวส.'),('major','DIGITAL_BUSINESS'),('nationality','THAI')]:page.locator(f'#{id}').select_option(val)
    page.locator('#nationalId').fill('0012345678901');page.locator('#email').fill('tester@example.test')
    page.locator('#send-otp').click();page.wait_for_function("document.querySelector('#otp-msg').textContent.includes('Mock OTP sent')",timeout=3000);assert page.locator('#send-otp').is_disabled();page.locator('#otp').fill('123456');page.locator('#email').fill('changed@example.test');assert page.locator('#otp').input_value()=='';assert 'อีเมลเปลี่ยน' in page.locator('#otp-timer').inner_text();page.locator('#email').fill('tester@example.test');page.locator('#otp').fill('123456');page.locator('#dataAck').check()
    calls=[0]
    def reg(route):
     calls[0]+=1
     if calls[0]==1:route.fulfill(status=502,content_type='application/json',body=json.dumps({'ok':False,'error':'Mock network loss'}),headers={'access-control-allow-origin':'*'})
     else:route.fulfill(status=200,content_type='application/json',body=json.dumps({'ok':True,'reference':'REF-TEST123'}),headers={'access-control-allow-origin':'*'})
    page.evaluate("window.TEST_REGISTER=async(url,opts)=>{window.TEST_PAYLOAD=JSON.parse(opts.body);window.TEST_CALLS=(window.TEST_CALLS||0)+1; return window.TEST_CALLS===1?new Response(JSON.stringify({ok:false,error:'Mock network loss'}),{status:502}):new Response(JSON.stringify({ok:true,reference:'REF-TEST123'}),{status:200});}; undefined")
    print('SUBMIT PRE COUNT',page.evaluate('window.TEST_CALLS||0'),flush=True);page.locator('#submit').click()
    page.wait_for_function("document.querySelector('#message').textContent.includes('Mock network loss')",timeout=3000)
    assert page.locator('#identity').input_value()=='00010001'
    assert page.locator('#submit').is_enabled()
    page.locator('#submit').click()
    page.wait_for_function("!document.querySelector('#success-panel').hidden")
    assert page.locator('#success-reference').inner_text()=='REF-TEST123'
    assert page.locator('#form').is_hidden()
    assert page.evaluate('document.activeElement.id')=='success-panel'
    assert page.evaluate('window.TEST_CALLS')==2
    assert page.evaluate('window.TEST_PAYLOAD.birthDate')=='2007-01-01'
    assert len(page.evaluate('window.TEST_PAYLOAD.requestId'))>=16
    assert not errors,errors
    passed.append('failed submit preserves input; retry succeeds; success panel focus and reference visible; no JS error')
    # Snapshot is optional; do not include users or mock credentials in source package.
    page.screenshot(path=str(root/'tests'/'viewport-360.png'),full_page=True)
   page.close()
  print('ADMIN',flush=True);admin=browser.new_page(viewport={'width':1280,'height':900})
  errs=[];admin.on('pageerror',lambda e:errs.append(str(e)))
  def server_route(route):
   if '/login' in route.request.url:route.fulfill(status=200,content_type='application/json',body='{"ok":true,"token":"MOCK"}',headers={'access-control-allow-origin':'*'})
   else:route.fulfill(status=502,content_type='application/json',body='{"ok":false,"error":"Mock stats unavailable"}',headers={'access-control-allow-origin':'*'})
  admin.evaluate("window.TEST_ADMIN=async(url)=>String(url).endsWith('/login')?new Response(JSON.stringify({ok:true,token:'MOCK'}),{status:200}):new Response(JSON.stringify({ok:false,error:'Mock stats unavailable'}),{status:502}); undefined")
  render(admin,'admin.html','admin.js')
  admin.locator('input[name=password]').fill('wrong-password-123');admin.evaluate("window.TEST_ADMIN=async(url)=>new Response(JSON.stringify({ok:false,error:'รหัสผ่านไม่ถูกต้อง'}),{status:401});undefined");admin.locator('#login-form button').click();admin.wait_for_function("document.querySelector('#login-msg').textContent.includes('รหัสผ่าน')",timeout=3000);assert not admin.locator('#login').is_hidden();admin.evaluate("window.TEST_ADMIN=async(url)=>String(url).endsWith('/login')?new Response(JSON.stringify({ok:true,token:'MOCK'}),{status:200}):new Response(JSON.stringify({ok:false,error:'Mock stats unavailable'}),{status:502}); undefined");admin.locator('input[name=password]').fill('valid-example-password')
  admin.locator('#login-form button').click()
  admin.wait_for_function("!document.querySelector('#app').hidden")
  assert 'Mock stats unavailable' in admin.locator('#stats-status').inner_text()
  assert admin.locator('#reload-stats').is_visible()
  assert not errs,errs
  passed.append('admin login success + stats failure shows retry without currentTarget error')
  admin.close();browser.close()
finally:pass
for x in passed:print('PASS',x)
