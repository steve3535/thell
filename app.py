from flask import Flask, request, render_template, redirect, url_for, flash
from flask_mail import Mail,Message
import random,subprocess  
PUBLIC_IP="94.252.100.127"
app = Flask(__name__)
app.secret_key = '123456'  # Needed for flashing messages

# Flask-Mail configuration
app.config['MAIL_SERVER'] = 'smtp.gmail.com'
app.config['MAIL_PORT'] = 587
app.config['MAIL_USE_TLS'] = True
app.config['MAIL_USERNAME'] = 'steve@thelinuxlabs.com'
app.config['MAIL_PASSWORD'] = 'wgwt yofk ywoj uhwb'
app.config['MAIL_DEFAULT_SENDER'] = 'steve@thelinuxlabs.com'
mail = Mail(app)

def gencreds():
    charset="abcdef0123456"
    return ''.join(random.choice(charset) for i in range(6))

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/submit_email', methods=['POST'])
def submit_email():
    email = request.form['email']
    # Process the email, e.g., save it to a database
    # print("Received email:", email)
    try:
        cmd_output=subprocess.run(['ssh',f'ubuntu@{PUBLIC_IP}','sudo','useradd','-m',email,'-s','/bin/bash'],text=True,capture_output=True)
        print(cmd_output)
    except Exception as e: 
        print(e)
    try:
      msg = Message("Registration Confirmation", recipients=[email])
      msg.body = f"Thank you for registering!\nusername = {email}\npassword  = {gencreds()}"
      mail.send(msg)
    except Exception as e:
        print("bad credentials for the mail or someth else ...",e)

    flash(f"Thank you for your registration ! Kindly check your email")
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(debug=True,host="0.0.0.0")
