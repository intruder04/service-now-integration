# -*- coding: utf-8 -*-
import requests, os
from config_file import *
script_path = os.path.dirname(__file__)

headers = {"Content-Type":"application/json","Accept":"application/json"}

class REST:
	def __init__(self, type, req_data=None, sd=None, sysid=None):
		self.type = type
		self.req_data = req_data if req_data is not None else ''
		self.sd = sd if sd is not None else ''
		self.sysid = sysid if sysid is not None else ''
		print('init',self.type,self.req_data,self.sd,self.sysid)
		
	def rest_request(self):
		global snhost_cfg
		resp_string = ''
		if self.type == 'post':
			self.req_data = self.req_data.encode("utf-8")
			response = requests.post(snhost_cfg, auth=(user_cfg, pwd_cfg), headers=headers ,data=self.req_data)
		elif self.type == 'get':
			url = snhost_cfg + '?sysparm_limit=1&u_external_id=' + self.sd
			response = requests.get(url, auth=(user_cfg, pwd_cfg), headers=headers)
		elif self.type == 'put':
			url = snhost_cfg + '/' + self.sysid
			response = requests.put(url, auth=(user_cfg, pwd_cfg), headers=headers ,data=self.req_data)
		if (response.status_code != 201) and (response.status_code != 200): 
			print('ERROR! Status:', response.status_code, 'Headers:', response.headers, 'Error Response:',response.json())
			raise
		else:
			# Decode the JSON response into a dictionary
			json_response = response.json()
			return json_response
		print ('response -',json_response)
		return json_response
		
	def check_sd_status(self, json):
		# Check if WO for self.sd already exists
		wo_number, wo_state, wo_sys_id = '','',''
		for key, value in json.items():
			for key_sub in value:
				for work_order_key, work_order_value in key_sub.items():
					if work_order_key == 'number':
						wo_number = work_order_value
					if work_order_key == 'state':
						wo_state = work_order_value
					if work_order_key == 'sys_id':
						wo_sys_id = work_order_value
		if wo_number == '':
			print ("no such SD -",self.sd,"have to create!!!\n")
			return 0
		else:
			print ("WO for",self.sd,"exists - ",wo_number,"and state ",wo_state,"and sysid ",wo_sys_id,".... bank id - ",self.sd,"\n")
			return wo_sys_id

	def get_data_for_xml(self, json):
		# Check if WO for self.sd already exists
		result_dict = {}
		for key, value in json.items():
			for key_sub in value:
				for work_order_key, work_order_value in key_sub.items():
					if work_order_key == 'number':
						result_dict['number'] = work_order_value
					if work_order_key == 'state':
						result_dict['state'] = work_order_value
					if work_order_key == 'u_close_code':
						result_dict['close_code'] = work_order_value
					if work_order_key == 'close_notes':
						result_dict['close_notes'] = work_order_value
		if result_dict['number'] == '':
			print ("no such SD -", self.sd)
			return 0
		else:
			print (result_dict)
			return result_dict
			
		