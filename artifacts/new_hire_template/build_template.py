from pathlib import Path
import json
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor, white
from reportlab.lib.utils import simpleSplit
from pypdf import PdfReader, PdfWriter
from pypdf.generic import DictionaryObject, NameObject, TextStringObject, ArrayObject

OUT=Path(__file__).resolve().parent
DATA={
 'schema':{'key':'newHire','version':'1.0'},
 'case':{'id':'500gK00000EXAMPLE','caseNumber':'00001042'},
 'request':{'requestDate':'2026-09-09','notificationType':'newHireRehire'},
 'employee':{'employeeId':'E-10042','firstName':'Jordan','lastName':'Rivera'},
 'assignment':{'region':'Central','district':'District 4','station':'Station 12','startDate':'2026-10-05','isRehire':False,'primaryTitle':'Paramedic','isDualRole':False,'department':'Operations','status':'New Hire','manager':'Alex Morgan','employmentStatus':'Full Time'},
 'certification':{'level':'EMT-Paramedic','txdshsNumber':'TX-88421','priorStateDetails':'NM-44109'},
 'compensation':{'currentHourlyOrSalary':'Above minimum','rateReason':'Market adjustment'},
 'notes':'Synthetic demo notes.\nInclude a second line to check multiline rendering.',
 'submitter':{'name':'Sam Patel','jobTitle':'Operations Supervisor','email':'sam.patel@example.test','attested':True}}
def flatten(d,p=''):
 r={}
 for k,v in d.items():
  key=f'{p}.{k}' if p else k
  if isinstance(v,dict):r.update(flatten(v,key))
  else:r[key]=str(v).lower() if isinstance(v,bool) else str(v)
 return r
flat=flatten(DATA)
navy=HexColor('#183349'); muted=HexColor('#506575'); line=HexColor('#91A5B4'); pale=HexColor('#F5F8FA')
fields=[]
c=canvas.Canvas(str(OUT/'new_hire_acroform.pdf'),pagesize=(612,792))
c.setTitle('Allegiance Mobile Health | New Hire AcroForm Template')
c.setAuthor('Allegiance Mobile Health')
def text(s,x,y,size=10,bold=False,color=navy):
 c.setFillColor(color);c.setFont('Helvetica-Bold' if bold else 'Helvetica',size);c.drawString(x,y,s)
def para(s,y,size=10,width=504):
 for ln in simpleSplit(s,'Helvetica',size,width):
  text(ln,54,y,size);y-=size+4
 return y

def page(n,title,sub):
 text('ALLEGIANCE MOBILE HEALTH',54,748,10,True)
 c.setStrokeColor(line);c.line(54,735,558,735)
 text(title,54,703,23,True);text(sub,54,681,10,color=muted)
 text('New hire / personnel change',54,32,8,color=muted)
 c.setFont('Helvetica',8);c.drawRightString(558,32,f'{n} / 4')

def section(s,y):
 c.setFillColor(pale);c.rect(54,y-8,504,25,fill=1,stroke=0);text(s,64,y,11,True)

def field(key,label,y,x=54,w=504,h=27,required=False,multi=False,hint=None):
 text(label+(' *' if required else ''),x,y,10,True)
 fy=y-h-9
 c.acroForm.textfield(name=key,tooltip=label+' ('+key+')',x=x,y=fy,width=w,height=h,value='',
  fontName='Helvetica',fontSize=10,textColor=navy,borderColor=line,fillColor=white,
  borderWidth=0.7,borderStyle='solid',forceBorder=True,maxlen=0,
  fieldFlags=' '.join(s for s,b in [('required',required),('multiline',multi)] if b))
 if hint:text(hint,x,fy-12,8,color=muted)
 fields.append({'name':key,'json_path':key,'type':'text','multiline':multi,'required':required,'page':len(c._doc.Pages.pages)+1,'label':label})

page(1,'New hire instructions','Complete the applicable sections before requesting approval.')
y=para('Please fully complete all sections of this form related to the change you are requesting. Multiple changes may be requested in a single form. Once the completed form is received, the approval process will begin. Should your request be declined, you will be notified.',644)
steps=[
('1','Applicant must apply for a job in Applicant Pro or from the company Careers page.'),
('2','Schedule and perform an interview with the applicant. Request any CCP/FP-C or prior/original certification documentation not on DSHS.'),
('3','Verify the certification effective date on DSHS and any prior/original certification documentation to determine the pay rate.'),
('4','Give a verbal offer of employment to the applicant.'),
('5','Inform the applicant they will receive a text/email to complete new-hire paperwork and a background/MVR check online via UltiPro (UKG Pro).'),
('6','Have the applicant sign the drug screen form, then administer the test.'),
('7','Have the applicant complete the Uniform Sizing Form and send it to the person who orders in your area.'),
('8','Take the applicant\'s picture: no hats, sunglasses, or piercings; include shoulders.'),
('9','Submit the PCN as soon as possible to start onboarding. Include drug screen authorization and results, the applicant\'s picture, and any CCP/FP-C or prior/original certification documents. HR will send the applicant a link for new-hire paperwork and background/MVR via UKG Pro.'),
('10','HR will inform the field once onboarding is complete and the applicant is approved to start.'),
('11','Add the applicant to the schedule and have the employee clock in on their first day.'),
('12','Once NEOP and virtual training are complete, send the NEOP packet to HRHelp@allmh.com.')]
y-=13
for n,s in steps:
 text(n.zfill(2),54,y,10,True); yy=y
 for ln in simpleSplit(s,'Helvetica',9.5,471):text(ln,87,yy,9.5);yy-=13
 y=yy-10
c.showPage()
page(2,'Employee & assignment','Fields marked with an asterisk (*) are required.')
section('Request and employee information',641)
field('request.notificationType','Notification type',610,required=True,hint='Enter the notification type from the request.')
field('request.requestDate',"Today’s date / request date".replace('’',"'"),538,x=54,w=242,hint='YYYY-MM-DD')
field('employee.employeeId','Employee ID #',538,x=316,w=242)
field('employee.firstName','Employee first name',466,x=54,w=242,required=True)
field('employee.lastName','Employee last name',466,x=316,w=242,required=True)
section('Assignment',394)
field('assignment.region','New region',362,x=54,w=242,required=True,hint='Enter NA if no changes.')
field('assignment.district','New district',362,x=316,w=242,required=True,hint='Enter NA if no changes.')
field('assignment.station','New station (or corporate location)',289,required=True,hint='Enter NA if no changes.')
field('assignment.startDate','Hire date / start date',216,x=54,w=242,hint='YYYY-MM-DD')
field('assignment.isRehire','Rehire?',216,x=316,w=242,hint='true / false')
field('assignment.primaryTitle','New primary title',144,required=True)
para('Notify HRHelp@allmh.com immediately if start date, FT/PRN status, or station changes, or if they will be a never worked.',81,8)
c.showPage()
page(3,'Role, certification & pay','Complete the new assignment and applicable certification details.')
field('assignment.isDualRole','Will this be a dual role?',639,x=54,w=242,hint='true / false')
field('assignment.department','New department',639,x=316,w=242)
field('assignment.status','New status',566,x=54,w=242)
field('assignment.employmentStatus','Status (Full Time / PRN)',566,x=316,w=242)
field('assignment.manager','New manager',499,required=True,hint='Enter NA if no changes.')
section('Certification',421)
field('certification.level','Certification level',390,x=54,w=242)
field('certification.txdshsNumber','TXDSHS certification #',390,x=316,w=242)
field('certification.priorStateDetails','Prior certification # / state',324,h=42,multi=True)
para('If certified in another state or holding an expired certification predating the DSHS date, provide the prior certification details and send supporting documentation to HRHelp@allmh.com.',254,8)
section('Compensation',205)
field('compensation.currentHourlyOrSalary','Current hourly / salary',174)
field('compensation.rateReason','New hire rate reason',109,h=32,multi=True)
c.showPage()
page(4,'Notes & authorization','Only authorized managers are allowed to submit forms.')
para('Submissions from unauthorized individuals may be rejected. If above minimum, a comment is required. If above maximum, approval documentation is required from Dan Gillespie and must be attached with supporting documentation.',644,9)
field('notes','Notes',576,h=91,multi=True)
para('Provide supporting documentation separately, including applicable employee communications, transfers, certifications, or pay changes. If received later, email HRHelp@allmh.com.',454,9)
field('submitter.name','Person completing form',396,required=True)
field('submitter.jobTitle','Person completing form job title',331,required=True)
field('submitter.email','Person completing form email address',266,required=True)
field('submitter.attested','Information reviewed and authorized',201,w=150,required=True,hint='true / false')
for i,ln in enumerate(simpleSplit('By entering true, I confirm that the information provided is accurate to the best of my knowledge and I am authorized to request or make this change.','Helvetica',8,337)):
 text(ln,221,188-i*12,8)
section('Record references',119)
field('case.caseNumber','Case number',92,x=54,w=112,h=20)
field('case.id','Case ID',92,x=178,w=172,h=20)
field('schema.key','Schema key',92,x=362,w=96,h=20)
field('schema.version','Version',92,x=470,w=88,h=20)
c.save()

# Use real parent/child fields: the fully qualified PDF name is the JSON path.
r=PdfReader(OUT/'new_hire_acroform.pdf');w=PdfWriter();w.clone_document_from_reader(r)
acro=w._root_object['/AcroForm'].get_object(); roots=ArrayObject();parents={}
for ref in acro['/Fields']:
 obj=ref.get_object();name=str(obj['/T'])
 if '.' not in name:roots.append(ref);continue
 group,leaf=name.split('.',1)
 if group not in parents:
  parent=DictionaryObject({NameObject('/T'):TextStringObject(group),NameObject('/Kids'):ArrayObject()})
  pref=w._add_object(parent);parents[group]=pref;roots.append(pref)
 pref=parents[group];pref.get_object()['/Kids'].append(ref)
 obj[NameObject('/T')]=TextStringObject(leaf);obj[NameObject('/Parent')]=pref
acro[NameObject('/Fields')]=roots
with open(OUT/'new_hire_acroform.pdf','wb') as f:w.write(f)

w=PdfWriter();w.clone_document_from_reader(PdfReader(OUT/'new_hire_acroform.pdf'))
w.update_page_form_field_values(list(w.pages),flat,auto_regenerate=False)
with open(OUT/'new_hire_filled_example.pdf','wb') as f:w.write(f)
(OUT/'user_data.example.json').write_text(json.dumps(DATA,indent=2)+'\n')
(OUT/'field_map.json').write_text(json.dumps(fields,indent=2)+'\n')

blank=PdfReader(OUT/'new_hire_acroform.pdf');filled=PdfReader(OUT/'new_hire_filled_example.pdf')
bf=blank.get_fields();ff=filled.get_fields()
leaf={k:v for k,v in bf.items() if v.get('/FT')}
assert set(leaf)==set(flat),(set(leaf)^set(flat))
for k,v in flat.items():
 assert leaf[k]['/FT']=='/Tx'
 assert str(leaf[k].get('/V',''))==''
 assert str(ff[k]['/V'])==v,(k,ff[k].get('/V'),v)
assert int(leaf['notes']['/Ff']) & 4096
assert all(len(p.extract_text())>400 for p in blank.pages)
assert all(not p.images for p in blank.pages)
assert len(blank.pages)==4
print(f'PASS: {len(leaf)} unique text fields, exact JSON paths; blank template and sample values verified; 4 selectable-text pages; no raster page images.')
import pypdfium2 as pdfium
from PIL import Image,ImageDraw
pdf=pdfium.PdfDocument(OUT/'new_hire_filled_example.pdf')
pdf.init_forms()
preview=Image.new('RGB',(1224,1584),'white')
for i,p in enumerate(pdf):preview.paste(p.render(scale=1).to_pil().convert('RGB'),((i%2)*612,(i//2)*792))
preview.save(OUT/'preview.png')
