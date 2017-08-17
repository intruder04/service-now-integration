# -*- coding: utf-8 -*-
from config_file import *
import os, time
import xml.etree.ElementTree as ET
from rest import REST


all_calls = []
xml_id_counter = 0

class Processing:
	
	def get_file_list(self):
		file_list = file_list_result = []
		file_list = os.listdir(xml_path_inb)
		for filename in os.listdir(xml_path_inb):
			fullname = os.path.join(xml_path_inb, filename)
			#ignore and delete empty files
			if os.path.getsize(fullname) == 0:
				self.move_xml_to_done(fullname,xml_done_path_inb)
				continue 
			#only xml files
			if not filename.endswith('.xml'): continue
			file_list_result.append(fullname)
		return file_list_result

	def create_call_list_from_xml(self,file_list):
		for filename in file_list:
			print('new file',filename)
			tree = ET.parse(filename)	
			# get root element
			root = tree.getroot()
			# iterate news instances
			for instance in root.findall('./DECLARATION/DECLGROUP/VALUE.OBJECT//INSTANCE'):
				properties_dict = {}
				properties_dict["CLASSNAME"] = instance.attrib['CLASSNAME']
				for child in instance:
					for property in child:
						properties_dict[child.attrib['NAME']] = property.text.replace("\"","")
				print('prop dict',properties_dict)
				all_calls.append(properties_dict)
			if move_processed_xmls_cfg == 1:
				self.move_xml_to_done(filename,xml_done_path_inb)
		return all_calls

	def create_xml_for_instance(self,data_dict,sber_id):
		print ('NUM',data_dict['number'])
		text_done = text_reject = ''
		text = '''
	<VALUE.OBJECT>
	<INSTANCE CLASSNAME="%(classname)s">
	<PROPERTY NAME="ID" TYPE="string">
		<VALUE>%(counter)s</VALUE>
	</PROPERTY>
	<PROPERTY NAME="СБ_ID" TYPE="string">
		<VALUE>%(sber_id)s</VALUE>
	</PROPERTY>
	<PROPERTY NAME="ИДЕНТИФИКАТОР" TYPE="string">
		<VALUE>%(number)s</VALUE>
	</PROPERTY>''' % {'classname': classname_status_dict[data_dict['state']], 'counter': self.increment(), 'sber_id': sber_id, 'number':data_dict['number']}

		if data_dict['state'] != 7 and classname_status_dict[data_dict['state']] == 'DONE':
			text_done = '''
	<PROPERTY NAME="РЕШЕНИЕ" TYPE="string">
		<VALUE>%(close_notes)s</VALUE>
	</PROPERTY>
	<PROPERTY NAME="КОД_ЗАКРЫТИЯ" TYPE="string">
		<VALUE>%(close_code)s</VALUE>
	</PROPERTY>
	<PROPERTY NAME="СТАТУС" TYPE="string">
		<VALUE>2</VALUE>
	</PROPERTY>''' % {'close_notes': data_dict['close_notes'], 'close_code': data_dict['close_code']}

		if data_dict['state'] == 7 and classname_status_dict[data_dict['state']] == 'DONE':
			text_done = '''
	<PROPERTY NAME="РЕШЕНИЕ" TYPE="string">
		<VALUE>%(close_notes)s</VALUE>
	</PROPERTY>
	<PROPERTY NAME="КОД_ЗАКРЫТИЯ" TYPE="string">
		<VALUE>8</VALUE>
	</PROPERTY>
	<PROPERTY NAME="СТАТУС" TYPE="string">
		<VALUE>8</VALUE>
	</PROPERTY>''' % {'close_notes': data_dict['close_notes']}

		text_end = '''
	</INSTANCE>
	</VALUE.OBJECT>	'''
		text = text + text_done + text_end

		print(text)
		return text

	def add_xml_headers(self,xmltext):
		xml_final = xml_start_cfg + xmltext + xml_end_cfg
		return xml_final

	def write_to_file(self,xmltext):
		file_path = os.path.join(xml_path_outb,xml_out_name_cfg)
		fh = open(file_path, 'w+')
		fh.write(xmltext)

	def get_sd_ids(self,calls):
		sd_ids = []
		for call in calls:
			for prop,value in call.items():
				if prop == 'СБ_ID' and value not in sd_ids:
					sd_ids.append(value)
		return sd_ids
		
	def make_req_tuple(self,call):
		type = req_data = ''
		if call['CLASSNAME']=='NEW':
			type = 'post'
			template = call['ШАБЛОН']
			sb_id = call['СБ_ID']
			short_descr = call['ТЕМА']
			descr = call['ИНФОРМАЦИЯ']
			caller = call['ИНИЦИАТОР']
			phone = call['ТЕЛЕФОН']
			reg_time = call['ВРЕМЯ_РЕГИСТРАЦИИ']
			srok_time = call['СРОК']
			desired_time = call['ЖЕЛАЕМАЯ_ДАТА']
			location = oktava_location_cfg
			req_data = "{\"description\":\"" + descr + "\",\"u_external_id\":\"" + sb_id + "\",\"short_description\":\"" + short_descr + "\",\"u_caller\":\"" + caller + "\",\"state\": \"10\",\"u_caller_phone\":\"" + phone + "\",\"u_glide_date_time_reg\":\"" + reg_time + "\",\"u_glide_date_time_srok\":\"" + srok_time + "\",\"u_glide_date_time_desired\":\"" + desired_time + "\",\"u_sberbank_template\":\"" + template + "\",\"work_notes\":\"\",\"location\":\""+location+"\",\"sysparm_input_display_value\":\"true\"}"
			req_data = req_data.replace('\r\n', '\\n')
			req_datas = req_data.replace('\t', '')
			return type,req_data,sb_id
		if call['CLASSNAME']=='REJECT':
			type = 'put'
			sb_id = call['СБ_ID']
			req_data = "{\"close_notes\":\"WO Cancelled!\",\"u_close_code\":\"8\"}"
			return type,req_data,sb_id
		else:
			return None,None,None
			
	def delete_file(self,file):
		os.remove(file)
		print (file, "have been deleted")
		
	def move_xml_to_done(self,source,destination):
		destination_with_xml = os.path.join(destination, os.path.basename(source))
		print ("moving",source,"to",destination_with_xml)
		os.replace(source, destination_with_xml)

	def file_exist(self,file_path):
		return os.path.isfile(file_path)


	def increment(self):
		global xml_id_counter
		xml_id_counter += 1
		return xml_id_counter





		
