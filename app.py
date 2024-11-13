from flask import Flask, request, Response
from flask_cors import CORS
from ruamel.yaml import YAML
from collections import OrderedDict
import subprocess
import json

app = Flask(__name__)

# Set up CORS for only specified origins, allowing requests from the frontend
CORS(app, resources={r"/*": {"origins": "http://localhost:3000"}})

CONFIG_PATH = 'egs-installer-config.yaml'
yaml = YAML()
yaml.default_flow_style = False  # Ensures block-style formatting
yaml.indent(mapping=2, sequence=4, offset=2)  # Sets indentation style for YAML

@app.route('/config', methods=['GET', 'POST'])
def config():
    print("Request method:", request.method)
    print("Request headers:", request.headers)

    if request.method == 'GET':
        # Load and return YAML configuration in JSON format, maintaining order
        with open(CONFIG_PATH, 'r') as file:
            config = yaml.load(file)  # YAML loader preserves order
        ordered_config = OrderedDict(config)  # Convert to OrderedDict for JSON serialization
        response_json = json.dumps(ordered_config)  # Serialize to JSON with order intact
        return Response(response_json, mimetype='application/json')

    elif request.method == 'POST':
        # Update YAML configuration with the incoming JSON data, preserving order
        new_config = request.json
        ordered_config = OrderedDict(new_config)  # Convert JSON to OrderedDict to preserve order
        with open(CONFIG_PATH, 'w') as file:
            yaml.dump(ordered_config, file)  # Save YAML with preserved order
        return Response(json.dumps({"message": "Config updated successfully"}), mimetype='application/json')

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