# -*- coding: utf-8 -*-
import os, configparser, smtplib, email, imaplib, sys, datetime
from io import StringIO
from email import encoders
from email.mime.base import MIMEBase
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from config_file import *

#get script path and create xml dirs:
# script_path = os.path.dirname(__file__)

class SendMail:
	COMMASPACE = ', '

	def __init__(self, subject, message, recipients, attachment):
		self.recipients_c = [recipients]
		self.subject_c = subject
		self.attachment_c = attachment
		self.message_c = message

	def compose_email(self):
		f_msg = MIMEMultipart()
		f_msg['Subject'] = self.subject_c
		f_msg['To'] = self.COMMASPACE.join(self.recipients_c)
		f_msg['From'] = mailsender_cfg
		f_msg.preamble = 'You will not see this in a MIME-aware mail reader.\n'
		f_msg.attach(MIMEText(self.message_c, 'plain'))
		if len(self.attachment_c) > 0 and self.attachment_c != None: 
			try:
				with open(self.attachment_c, 'rb') as fp:
					msg = MIMEBase('application', "octet-stream")
					msg.set_payload(fp.read())
				encoders.encode_base64(msg)
				msg.add_header('Content-Disposition', 'attachment', filename=os.path.basename(self.attachment_c))
				f_msg.attach(msg)
			except:
				print("Error! Unable to open attachment")
				raise
			composed = f_msg.as_string()
			return composed
		else:
			print("no attachment arg\n")
			composed = f_msg.as_string()
			return composed

	def send_email(self, composed):
		global mailuser_cfg,mailpass_cfg
		try:
			with smtplib.SMTP_SSL('smtp.mail.ru', 465) as s:
				s.login(mailuser_cfg, mailpass_cfg)
				s.sendmail(mailsender_cfg, self.recipients_c, composed)
				s.close()
			print("Email sent!")
		except:
			print("Error! Unable to send the email")
			raise
			
class GetMail:
	def recieve_mail(self):
		detach_dir = '.'
		if 'attachments' not in os.listdir(detach_dir):
			os.mkdir('attachments')

		imapSession = imaplib.IMAP4_SSL('imap.mail.ru')
		typ, accountDetails = imapSession.login(mailsender_cfg, mailpass_cfg)
		if typ != 'OK':
			print ('Not able to sign in!')
			raise
			
		imapSession.select('INBOX')
		typ, data = imapSession.search(None, 'ALL')
		if typ != 'OK':
			print ('Error searching Inbox.')
			raise

		# Iterating over all emails
		for msgId in data[0].split():
			typ, messageParts = imapSession.fetch(msgId, '(RFC822)')
			if typ != 'OK':
				print ('Error fetching mail.')
				raise

			emailBody = messageParts[0][1]
			# print (emailBody)
			mail = email.message_from_bytes(emailBody)
			for part in mail.walk():
				if part.get_content_maintype() == 'multipart':
					#print part.as_string()
					continue
				if part.get('Content-Disposition') is None:
					#print part.as_string()
					continue
				fileName = part.get_filename()
				print(fileName)
				if fileName:
					filePath = os.path.join(script_path, 'xml', 'in', fileName + str(datetime.datetime.now().strftime('%Y-%m-%d-%H-%M-%S-%f')) + ".xml")
					print(filePath)
					fp = open(filePath, 'wb')
					fp.write(part.get_payload(decode=True))
					fp.close()
			if remove_email_cfg == 1:
				imapSession.store(msgId, '+FLAGS', '\\Deleted')

		imapSession.close()
		imapSession.logout()