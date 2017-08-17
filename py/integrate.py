# -*- coding: utf-8 -*-
from config_file import *
from mail import SendMail 
from mail import GetMail
from rest import REST
from xparser import Processing
import os

GetMail().recieve_mail()

# exit()
process_xmls = Processing()
xml_file_list = process_xmls.get_file_list()
calls_list = process_xmls.create_call_list_from_xml(xml_file_list)
sd_ids = process_xmls.get_sd_ids(calls_list)

for call in calls_list:
	req_tuple = process_xmls.make_req_tuple(call)
	print ('reqstring',req_tuple)
	if (req_tuple[0] == 'post') or (req_tuple[0] == 'put'):

		# check if work order for SD already exist. WO must have sys_id
		req_obj_check = REST('get','',req_tuple[2],'')
		req_check = req_obj_check.rest_request()
		sys_id = req_obj_check.check_sd_status(req_check)

		# if no SD and post - create SD
		if (sys_id == 0) and (req_tuple[0] == 'post'):
			print('POST here\n')
			post_obj = REST(req_tuple[0],req_tuple[1],req_tuple[2])
			req = post_obj.rest_request()

		# if sd exists and put - make reject
		elif (sys_id != 0) and (req_tuple[0] == 'put'):
			print('PUT here\n')
			put_obj = REST(req_tuple[0],req_tuple[1],req_tuple[2])
			req = post_obj.rest_request()
		else:
			print('DID NOTHING\n')







print ("have to create xml for:", sd_ids)		

xml_instances = ''
for call in sd_ids:
	test = REST('get','',call,'')
	test2 = test.rest_request()
	test3 = test.get_data_for_xml(test2)
	xml_instance = process_xmls.create_xml_for_instance(test3,call)
	xml_instances = xml_instances + xml_instance

final_outb_xml = process_xmls.add_xml_headers(xml_instances)
process_xmls.write_to_file(final_outb_xml)

if process_xmls.file_exist(outbound_xml_cfg):
	MailObjSend = SendMail('hello', 'тест', 'may.viktor@gmail.com', outbound_xml_cfg)
	MailObjSend.send_email(MailObjSend.compose_email())

	os.replace(os.path.join(xml_path_outb,xml_out_name_cfg), os.path.join(xml_done_path_outb,xml_out_name_cfg))



