#!/usr/bin/python
# vim: set tabstop=8 expandtab shiftwidth=4 softtabstop=4
# TODO(omadjoudj): Convert this script into Jenkins pipeline


import json
import os
import random
import requests
import string

#TODO(omadjoudj): Check env variables before using them
#eg: SALT_API_URL=http://127.0.0.1:6969/run
SALT_API_URL = os.environ['SALT_API_URL']
SALT_API_PASSWORD = os.environ['SALT_API_PASSWORD']
SALT_API_COMMON_OPTIONS = {'eauth': 'pam', 'username': 'salt', 'client': 'local'}

def get_opscare_users(salt_api_url=SALT_API_URL, salt_api_password=SALT_API_PASSWORD):
    post_data=SALT_API_COMMON_OPTIONS.copy()
    post_data['password'] = SALT_API_PASSWORD
    post_data['tgt'] = 'cfg*'
    post_data['fun'] = 'cmd.run'
    #TODO(omadjoudj): get the user list from pillars instead (check opscare-reclass)
    post_data['arg'] = r'cat /etc/group | grep -E "support_csm|support3|support_l0" | cut -d: -f4 | tr "\n" ","  | tr "," " "'
    resp = requests.post(SALT_API_URL, data=post_data)
    return json.loads(resp.text)['return'][0].values()[0].split(' ')

#TODO(omadjoudj): Return something useful
def update_users_password(salt_api_url, salt_api_password, user_list):
    post_data=SALT_API_COMMON_OPTIONS.copy()
    post_data['password'] = SALT_API_PASSWORD
    post_data['tgt'] = '*'
    post_data['fun'] = 'cmd.run'
    for user in user_list:
        new_password = ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(32))
        post_data['arg'] = 'echo {}:{} | chpasswd '.format(user,new_password)
        #print(post_data)    
        resp = requests.post(SALT_API_URL, data=post_data)




###


if __name__ == '__main__':
    update_users_password(salt_api_url=SALT_API_URL, salt_api_password=SALT_API_PASSWORD,user_list=get_opscare_users())