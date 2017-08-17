# -*- coding: utf-8 -*-
import os

script_path = os.path.dirname(__file__)
xml_path_inb = os.path.join(script_path, 'xml' , 'in')
xml_done_path_inb = os.path.join(script_path, 'xml' , 'in', 'done')
xml_path_outb = os.path.join(script_path, 'xml' , 'out')
xml_done_path_outb = os.path.join(script_path, 'xml' , 'out', 'done')



# global snhost
snhost_cfg = 'https://sberbankpov.service-now.com'+'/api/now/table/wm_order'

#sn
user_cfg = 
pwd_cfg = 
#mail
mailuser_cfg = 
mailsender_cfg = 
mailpass_cfg = 
remove_email_cfg = 1
move_processed_xmls_cfg = 1

xml_out_name_cfg = 'from_oktava.xml'
outbound_xml_cfg = os.path.join(xml_path_outb,xml_out_name_cfg)


oktava_location_cfg = '9fbd89294f383e0053e91aabb110c7a8'


### STATUS - CLASSNAME DICT
#IN_PROGRESS
classname_status_dict = {'1': 'IN_PROGRESS', '10': 'IN_PROGRESS', '16': 'IN_PROGRESS', '17': 'IN_PROGRESS', '18': 'IN_PROGRESS'}

#DONE
classname_status_dict["3"] = 'DONE'
classname_status_dict["4"] = 'DONE'

#REJECT
classname_status_dict["7"] = 'DONE'


xml_start_cfg = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE CIM PUBLIC "SYSTEM" "CIM_DTD_V20.dtd"[
<!ENTITY lt      "&#38;#60;">
<!ENTITY gt      "&#62;">
<!ENTITY amp     "&#38;#38;">
<!ENTITY apos    "&#39;">
<!ENTITY quot    "&#34;">]>
<CIM CIMVERSION="2.0" DTDVERSION="2.2">
<DECLARATION>
<DECLGROUP>
<VALUE.OBJECT>
<INSTANCE CLASSNAME="Header">
<PROPERTY NAME="Date" TYPE="string">
	<VALUE>' . "$date_string" . '</VALUE>
</PROPERTY>
<PROPERTY NAME="Application" TYPE="string">
	<VALUE>ServiceNow TMC</VALUE>
</PROPERTY>
</INSTANCE>
</VALUE.OBJECT>'''

xml_end_cfg = '''
</DECLGROUP>
</DECLARATION>
</CIM>'''


if 'xml' not in os.listdir(script_path):
	os.mkdir(os.path.join(script_path, 'xml'))
if 'in' not in os.listdir(os.path.join(script_path, 'xml')):
	os.mkdir(os.path.join(script_path, 'xml' , 'in'))
if 'done' not in os.listdir(os.path.join(script_path, 'xml', 'in')):
	os.mkdir(os.path.join(script_path, 'xml' , 'in', 'done'))
if 'out' not in os.listdir(os.path.join(script_path, 'xml')):
	os.mkdir(os.path.join(script_path, 'xml' , 'out'))
if 'done' not in os.listdir(os.path.join(script_path, 'xml', 'out')):
	os.mkdir(os.path.join(script_path, 'xml' , 'out', 'done'))

