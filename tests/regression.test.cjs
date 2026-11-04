'use strict';
const fs=require('fs'),vm=require('vm'),crypto=require('crypto'),assert=require('node:assert/strict');
const maps=new Map(),emails=[];
class Sheet {
 constructor(name){this.name=name;this.rows=[];this.failNextAppend=false;}
 getLastRow(){for(let i=this.rows.length-1;i>=0;i--)if(this.rows[i]?.some(v=>v!==''&&v!==null&&v!==undefined))return i+1;return 0;}
 getMaxRows(){return 1000;} setFrozenRows(){return this;}
 appendRow(v){if(this.failNextAppend){this.failNextAppend=false;throw Error('INJECTED partial sheet failure');}this.rows.push(v.map(x=>String(x??'')));return this;}
 getRange(row,col,h=1,w=1){const s=this;return {setValues(arr){for(let i=0;i<h;i++){const r=row+i-1;s.rows[r]??=[];for(let j=0;j<w;j++)s.rows[r][col+j-1]=String(arr[i][j]??'');}return this;},getDisplayValues(){return Array.from({length:h},(_,i)=>Array.from({length:w},(_,j)=>String(s.rows[row+i-1]?.[col+j-1]??'')));},setValue(v){return this.setValues([[v]]);},setNumberFormat(){return this;},setBackground(){return this;},setFontWeight(){return this;}};}
}
const book={getSheetByName(n){return maps.get(n)||null;},insertSheet(n){const s=new Sheet(n);maps.set(n,s);return s;}};
const context=vm.createContext({console,Date,Math,JSON,Number,String,Array,Object,parseInt,Error,RegExp,getSharedSecret_:()=> 'local_dummy_only',SpreadsheetApp:{getActiveSpreadsheet:()=>book},MailApp:{getRemainingDailyQuota:()=>999,sendEmail:v=>emails.push(v)},LockService:{getScriptLock:()=>({waitLock(){},releaseLock(){}})},Utilities:{computeDigest:(_,x)=>Array.from(crypto.createHash('sha256').update(x).digest()),DigestAlgorithm:{SHA_256:'SHA_256'},getUuid:()=>crypto.randomUUID(),formatDate:()=> '2026-11-04'},ContentService:{createTextOutput:x=>({text:x,setMimeType(){return this;}}),MimeType:{JSON:'json'}}});
vm.runInContext(fs.readFileSync(__dirname+'/../apps-script/Code.gs','utf8'),context);
const call=(fn,arg)=>vm.runInContext(`${fn}(${JSON.stringify(arg||{})})`,context);
const text=(v)=>String(v);
assert.equal(call('settingsSave_',{registrationOpen:true,bankExportEnabled:true,defaultFacultyId:'F001'}).ok,true);
const otpResult=call('requestOtp_',{email:'alpha@example.test'});assert.equal(otpResult.retryAfter,90);assert.equal(otpResult.expiresIn,600);
const tooFast=call('requestOtp_',{email:'alpha@example.test'});assert.equal(tooFast.ok,false);assert(tooFast.retryAfter>0);
const otp=emails.at(-1).body.match(/\d{6}/)[0];
const original={role:'STUDENT',identity:'00012001',email:'alpha@example.test',prefix:'MISS',gender:'FEMALE',firstTh:'ทดสอบ',lastTh:'นักศึกษา',firstEn:'Test',lastEn:'Example',birthDate:'2008-01-02',degree:'DIPLOMA',studyYear:'1',currentLevel:'ปวส.',major:'DIGITAL_BUSINESS',nationality:'THAI',nationalId:'0012345678901',dataAck:true,bankPermission:true,otp,requestId:'4f83e5c9-d8a2-451a-9b2f-abcdef000001'};
assert.equal(call('register_',{...original,otp:'123123'}).ok,false);
const extras=maps.get('RegistrationExtra');extras.failNextAppend=true;
assert.throws(()=>call('register_',original),/INJECTED/);
assert.equal(call('users_',{offset:0}).total,1,'user row was saved prior to failure');
assert.equal(extras.getLastRow(),1,'extra not written');
const recovered=call('register_',original);assert.equal(recovered.ok,true);assert.equal(extras.getLastRow(),2);assert.equal(maps.get('RegistrationJournal').getLastRow(),2);
const replay=call('register_',original);assert.equal(replay.replayed,true);assert.equal(replay.reference,recovered.reference);assert.equal(call('users_',{offset:0}).total,1);
assert.equal(call('register_',{...original,bankPermission:false}).ok,false,'same id must not reveal or mutate other payload');
assert.equal(call('register_',{...original,otp:'000000'}).ok,false,'request-id alone not proof');
const base=call('users_',{offset:0}).rows[0];
const next=(id,email,citizen)=>{const out=Array.from(base);out[0]=id;out[1]=id;out[3]=email;out[20]=citizen;return out;};
const r1=next('00012002','beta@example.test','0012345678902');
const r2=next('00012003','BETA@example.test','0012345678903');
const r3=next('00012004','gamma@example.test','0012345678902');
const imports=call('adminImport_',{rows:[r1,r2,r3],rowNumbers:[2,5,7]});
assert.equal(imports.added,1);assert.equal(imports.rejected,2);assert.equal(imports.errors[0].row,5);assert(/Email/.test(imports.errors[0].reason));assert.equal(imports.errors[1].row,7);assert(/Citizen/.test(imports.errors[1].reason));
const across=call('adminImport_',{rows:[next('00012005','beta@example.test','0012345678905')],startRow:32});
assert.equal(across.added,0);assert.equal(across.errors[0].row,32);
const invalid=next('00012006','zeta@example.test','0012345678906');invalid[14]='UNKNOWN';
assert.equal(call('adminImport_',{rows:[invalid],startRow:100}).errors[0].row,100);
const edit=Array.from(base);edit[3]='BETA@example.test';assert.equal(call('userSave_',{id:base[0],values:edit}).ok,false);
const notReady=call('export_',{offset:0});assert.equal(notReady.total,1);assert.equal(notReady.excludedCount,1);assert(notReady.excluded[0].reason.includes('ความยินยอม'));
const otpOther=call('requestOtp_',{email:'expired@example.test'});assert(otpOther.ok);const expRows=maps.get('EmailOTP').rows;const last=expRows.length-1;expRows[last][3]='2000-01-01T00:00:00Z';
const expired=call('register_',{...original,email:'expired@example.test',identity:'00012007',nationalId:'0012345678907',otp:emails.at(-1).body.match(/\d{6}/)[0],requestId:'4f83e5c9-d8a2-451a-9b2f-abcdef000007'});assert.equal(expired.ok,false);
console.log('PASS regression: OTP cooldown/expiry/bad OTP, partial recovery, replay proof, privacy, duplicate file and cross-batch, exact Excel row numbers, export exclusion, admin edit validation');
