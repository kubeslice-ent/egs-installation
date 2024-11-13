from flask import Flask, request, Response
from flask_cors import CORS
import subprocess
import json
import os


app = Flask(__name__)

# Set up CORS for only specified origins, allowing requests from the frontend
CORS(app, resources={r"/*": {"origins": "http://localhost:3000"}})

CONFIG_PATH = 'egs-installer-config.yaml'

def get_config():
    # Use yq to convert YAML to JSON for the response
    result = subprocess.run(['yq', '-o=json', CONFIG_PATH], capture_output=True, text=True)
    if result.returncode == 0:
        return json.loads(result.stdout)
    else:
        raise RuntimeError("Failed to read YAML config with yq")

def update_config(new_config):
    # Use yq for each field to update the YAML file in place
    for key, value in new_config.items():
        # Check if the value is boolean and convert to lowercase string explicitly
        if isinstance(value, bool):
            value_str = 'true' if value else 'false'
            subprocess.run(['yq', f'.{key} = {value_str}', '-i', CONFIG_PATH])
        elif isinstance(value, dict) or isinstance(value, list):
            value_json = json.dumps(value)
            subprocess.run(['yq', f'.{key} = {value_json}', '-i', CONFIG_PATH])
        else:
            subprocess.run(['yq', f'.{key} = "{value}"', '-i', CONFIG_PATH])
    
    # Post-process the file to ensure booleans are lowercase
    os.system(f"sed -i 's/\\bTrue\\b/true/g; s/\\bFalse\\b/false/g' {CONFIG_PATH}")

@app.route('/config', methods=['GET', 'POST'])
def config():
    print("Request method:", request.method)
    print("Request headers:", request.headers)

    if request.method == 'GET':
        try:
            config_data = get_config()
            return Response(json.dumps(config_data), mimetype='application/json')
        except RuntimeError as e:
            return Response(json.dumps({"error": str(e)}), status=500, mimetype='application/json')

    elif request.method == 'POST':
        new_config = request.json
        try:
            update_config(new_config)
            return Response(json.dumps({"message": "Config updated successfully"}), mimetype='application/json')
        except RuntimeError as e:
            return Response(json.dumps({"error": str(e)}), status=500, mimetype='application/json')

def stream_process(command):
    # Generator to yield output from a shell command in real-time
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    for line in iter(process.stdout.readline, ''):
        yield f"data: {line}\n"
    process.stdout.close()
    process.wait()
    yield f"data: \nProcess finished with exit code {process.returncode}\n"

def stream_response(command):
    # Wrap stream_process to provide a Response object with streaming headers
    return Response(stream_process(command), mimetype='text/event-stream')

@app.route('/install', methods=['POST'])
def run_install():
    # Trigger streaming for the install process
    command = ['./egs-installer.sh', '--input-yaml', CONFIG_PATH]
    return stream_response(command)

@app.route('/uninstall', methods=['POST'])
def run_uninstall():
    # Trigger streaming for the uninstall process
    command = ['./egs-uninstall.sh', '--input-yaml', CONFIG_PATH]
    return stream_response(command)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)