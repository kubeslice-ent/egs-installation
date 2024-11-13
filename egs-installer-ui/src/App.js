import React, { useState, useEffect } from 'react';
import axios from 'axios';
import {
    Container, TextField, Checkbox, FormControlLabel, Button, Typography, CircularProgress, Alert, Box, Paper, Stepper, Step, StepLabel
} from '@mui/material';
import yaml from 'js-yaml';
import _ from 'lodash';

const BASE_URL = 'http://127.0.0.1:5001';

function WizardApp() {
    const [config, setConfig] = useState({});
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [terminalOutput, setTerminalOutput] = useState('');
    const [activeStep, setActiveStep] = useState(0);

    const steps = ['Basic Settings', 'Kubernetes & Helm Config', 'Component Settings', 'Project & Cluster Setup', 'Additional Config', 'Review & Execute'];

    useEffect(() => {
        fetchConfig();
    }, []);

    const fetchConfig = async () => {
        setLoading(true);
        try {
            const response = await axios.get(`${BASE_URL}/config`);
            setConfig(response.data);
        } catch (error) {
            console.error('Error fetching config:', error);
            setError('Error fetching config');
        } finally {
            setLoading(false);
        }
    };

    const saveConfig = async () => {
        try {
            await axios.post(`${BASE_URL}/config`, config);
            alert('Config saved successfully');
        } catch (error) {
            console.error('Error saving config:', error);
            setError('Error saving config');
        }
    };

    const streamToTerminal = async (endpoint) => {
        setTerminalOutput('');
        try {
            const response = await fetch(`${BASE_URL}/${endpoint}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' }
            });
            const reader = response.body.getReader();
            const decoder = new TextDecoder("utf-8");
            while (true) {
                const { done, value } = await reader.read();
                if (done) break;
                setTerminalOutput((prev) => prev + decoder.decode(value));
            }
        } catch (error) {
            console.error(`Error with ${endpoint}:`, error);
            setError(`Error with ${endpoint}`);
        }
    };

    const handleNext = () => setActiveStep((prev) => prev + 1);
    const handleBack = () => setActiveStep((prev) => prev - 1);

    const handleChange = (path, value) => {
        setConfig((prevConfig) => ({ ...prevConfig, [path]: value }));
    };

    const handleArrayAdd = (path) => {
        setConfig((prevConfig) => {
            const newConfig = _.cloneDeep(prevConfig);
            const array = _.get(newConfig, path, []);
            const newItem = path === 'commands' ? {
                use_global_kubeconfig: false,
                skip_installation: false,
                verify_install: false,
                verify_install_timeout: 0,
                skip_on_verify_fail: false,
                namespace: '',
                command_stream: ''
            } : {};
            array.push(newItem);
            _.set(newConfig, path, array);
            return newConfig;
        });
    };

    const handleArrayRemove = (path, index) => {
        setConfig((prevConfig) => {
            const newConfig = _.cloneDeep(prevConfig);
            const array = _.get(newConfig, path, []);
            array.splice(index, 1);
            _.set(newConfig, path, array);
            return newConfig;
        });
    };

    const handleArrayFieldChange = (path, value) => {
        setConfig((prevConfig) => {
            const newConfig = _.cloneDeep(prevConfig);
            _.set(newConfig, path, value);
            return newConfig;
        });
    };

    const renderStepContent = (step) => {
        switch (step) {
            case 0:
                return (
                    <Box>
                        <Typography variant="h6">General Settings</Typography>
                        <Box mb={2}>
                            <TextField label="Base Path" value={config.base_path || ''} onChange={(e) => handleChange('base_path', e.target.value)} fullWidth />
                        </Box>
                        <Box mb={2}>
                            <FormControlLabel
                                control={<Checkbox checked={config.precheck || false} onChange={(e) => handleChange('precheck', e.target.checked)} />}
                                label="Precheck"
                            />
                        </Box>
                        <Box mb={2}>
                            <FormControlLabel
                                control={<Checkbox checked={config.verify_install || false} onChange={(e) => handleChange('verify_install', e.target.checked)} />}
                                label="Verify Install"
                            />
                        </Box>
                        <Box mb={2}>
                            <TextField label="Verify Timeout" type="number" value={config.verify_install_timeout || ''} onChange={(e) => handleChange('verify_install_timeout', e.target.value)} fullWidth />
                        </Box>
                        <Box mb={2}>
                            <TextField label="Global Helm Repo URL" value={config.global_helm_repo_url || ''} onChange={(e) => handleChange('global_helm_repo_url', e.target.value)} fullWidth />
                        </Box>
                        <Box mb={2}>
                            <TextField label="Helm Username" value={config.global_helm_username || ''} onChange={(e) => handleChange('global_helm_username', e.target.value)} fullWidth />
                        </Box>
                        <Box mb={2}>
                            <TextField label="Helm Password" type="password" value={config.global_helm_password || ''} onChange={(e) => handleChange('global_helm_password', e.target.value)} fullWidth />
                        </Box>
                    </Box>
                );
            case 1:
                return (
                    <Box>
                        <Typography variant="h6">Kubernetes & Contexts</Typography>
                        <Box mb={2}>
                            <TextField label="Kubeconfig Path" value={config.global_kubeconfig || ''} onChange={(e) => handleChange('global_kubeconfig', e.target.value)} fullWidth />
                        </Box>
                        <Box mb={2}>
                            <TextField label="Kubecontext" value={config.global_kubecontext || ''} onChange={(e) => handleChange('global_kubecontext', e.target.value)} fullWidth />
                        </Box>
                        <Box mb={2}>
                            <FormControlLabel
                                control={<Checkbox checked={config.use_global_context || false} onChange={(e) => handleChange('use_global_context', e.target.checked)} />}
                                label="Use Global Context"
                            />
                        </Box>
                        <Box mb={2}>
                            <FormControlLabel
                                control={<Checkbox checked={config.readd_helm_repos || false} onChange={(e) => handleChange('readd_helm_repos', e.target.checked)} />}
                                label="Re-add Helm Repos"
                            />
                        </Box>
                    </Box>
                );
            case 2:
                return (
                    <Box>
                        <Typography variant="h6">Component Settings</Typography>
                        <Box mb={2}>
                            <FormControlLabel
                                control={<Checkbox checked={config.enable_install_controller || false} onChange={(e) => handleChange('enable_install_controller', e.target.checked)} />}
                                label="Install Controller"
                            />
                        </Box>
                        <Box mb={2}>
                            <FormControlLabel
                                control={<Checkbox checked={config.enable_install_ui || false} onChange={(e) => handleChange('enable_install_ui', e.target.checked)} />}
                                label="Install UI"
                            />
                        </Box>
                        <Box mb={2}>
                            <FormControlLabel
                                control={<Checkbox checked={config.enable_install_worker || false} onChange={(e) => handleChange('enable_install_worker', e.target.checked)} />}
                                label="Install Worker"
                            />
                        </Box>
                        <Box mt={3}>
                            <Typography variant="subtitle1">Worker Configurations</Typography>
                            {(config.kubeslice_worker_egs || []).map((workerConfig, index) => (
                                <Box key={index} sx={{ marginBottom: 2, padding: 2, border: '1px solid #ddd', borderRadius: '4px' }}>
                                    <Typography variant="subtitle2">Worker {index + 1}</Typography>
                                    <Box mb={2}>
                                        <TextField label="Worker Name" value={workerConfig.name || ''} onChange={(e) => handleArrayFieldChange(`kubeslice_worker_egs[${index}].name`, e.target.value)} fullWidth />
                                    </Box>
                                    <Box mb={2}>
                                        <TextField label="Worker Image" value={workerConfig.image || ''} onChange={(e) => handleArrayFieldChange(`kubeslice_worker_egs[${index}].image`, e.target.value)} fullWidth />
                                    </Box>
                                    <Button variant="outlined" color="error" onClick={() => handleArrayRemove('kubeslice_worker_egs', index)}>Remove Worker</Button>
                                </Box>
                            ))}
                            <Button variant="outlined" color="primary" onClick={() => handleArrayAdd('kubeslice_worker_egs')}>Add Worker</Button>
                        </Box>
                    </Box>
                );
            case 3:
                return (
                    <Box>
                        <Typography variant="h6">Project & Cluster Setup</Typography>
                        <Box mt={3}>
                            <Typography variant="subtitle1">Projects</Typography>
                            {(config.projects || []).map((project, index) => (
                                <Box key={index} sx={{ marginBottom: 2, padding: 2, border: '1px solid #ddd', borderRadius: '4px' }}>
                                    <Typography variant="subtitle2">Project {index + 1}</Typography>
                                    <Box mb={2}>
                                        <TextField label="Project Name" value={project.name || ''} onChange={(e) => handleArrayFieldChange(`projects[${index}].name`, e.target.value)} fullWidth />
                                    </Box>
                                    <Box mb={2}>
                                        <TextField label="Project Description" value={project.description || ''} onChange={(e) => handleArrayFieldChange(`projects[${index}].description`, e.target.value)} fullWidth />
                                    </Box>
                                    <Button variant="outlined" color="error" onClick={() => handleArrayRemove('projects', index)}>Remove Project</Button>
                                </Box>
                            ))}
                            <Button variant="outlined" color="primary" onClick={() => handleArrayAdd('projects')}>Add Project</Button>
                        </Box>
                        <Box mt={3}>
                            <Typography variant="subtitle1">Cluster Registration</Typography>
                            {(config.cluster_registration || []).map((cluster, index) => (
                                <Box key={index} sx={{ marginBottom: 2, padding: 2, border: '1px solid #ddd', borderRadius: '4px' }}>
                                    <Typography variant="subtitle2">Cluster {index + 1}</Typography>
                                    <Box mb={2}>
                                        <TextField label="Cluster Name" value={cluster.name || ''} onChange={(e) => handleArrayFieldChange(`cluster_registration[${index}].name`, e.target.value)} fullWidth />
                                    </Box>
                                    <Box mb={2}>
                                        <TextField label="Cluster URL" value={cluster.url || ''} onChange={(e) => handleArrayFieldChange(`cluster_registration[${index}].url`, e.target.value)} fullWidth />
                                    </Box>
                                    <Button variant="outlined" color="error" onClick={() => handleArrayRemove('cluster_registration', index)}>Remove Cluster</Button>
                                </Box>
                            ))}
                            <Button variant="outlined" color="primary" onClick={() => handleArrayAdd('cluster_registration')}>Add Cluster</Button>
                        </Box>
                    </Box>
                );
            case 4:
                return (
                    <Box>
                        <Typography variant="h6">Additional Configurations</Typography>
                        <Box mt={3}>
                            <Typography variant="subtitle1">Additional Applications</Typography>
                            {(config.additional_apps || []).map((app, index) => (
                                <Box key={index} sx={{ marginBottom: 2, padding: 2, border: '1px solid #ddd', borderRadius: '4px' }}>
                                    <Typography variant="subtitle2">App {index + 1}</Typography>
                                    <Box mb={2}>
                                        <TextField label="App Name" value={app.name || ''} onChange={(e) => handleArrayFieldChange(`additional_apps[${index}].name`, e.target.value)} fullWidth />
                                    </Box>
                                    <Box mb={2}>
                                        <TextField label="App Version" value={app.version || ''} onChange={(e) => handleArrayFieldChange(`additional_apps[${index}].version`, e.target.value)} fullWidth />
                                    </Box>
                                    <Button variant="outlined" color="error" onClick={() => handleArrayRemove('additional_apps', index)}>Remove App</Button>
                                </Box>
                            ))}
                            <Button variant="outlined" color="primary" onClick={() => handleArrayAdd('additional_apps')}>Add Application</Button>
                        </Box>
                        <Box mt={3}>
                            <Typography variant="h6">Custom Commands</Typography>
                            {(config.commands || []).map((command, index) => (
                                <Box key={index} sx={{ marginBottom: 2, padding: 2, border: '1px solid #ddd', borderRadius: '4px' }}>
                                    <Typography variant="subtitle2">Command Set {index + 1}</Typography>
                                    <Box mb={2}>
                                        <FormControlLabel
                                            control={<Checkbox checked={command.use_global_kubeconfig || false} onChange={(e) => handleArrayFieldChange(`commands[${index}].use_global_kubeconfig`, e.target.checked)} />}
                                            label="Use Global Kubeconfig"
                                        />
                                    </Box>
                                    <Box mb={2}>
                                        <FormControlLabel
                                            control={<Checkbox checked={command.skip_installation || false} onChange={(e) => handleArrayFieldChange(`commands[${index}].skip_installation`, e.target.checked)} />}
                                            label="Skip Installation"
                                        />
                                    </Box>
                                    <Box mb={2}>
                                        <FormControlLabel
                                            control={<Checkbox checked={command.verify_install || false} onChange={(e) => handleArrayFieldChange(`commands[${index}].verify_install`, e.target.checked)} />}
                                            label="Verify Install"
                                        />
                                    </Box>
                                    <Box mb={2}>
                                        <TextField label="Verify Install Timeout" type="number" value={command.verify_install_timeout || ''} onChange={(e) => handleArrayFieldChange(`commands[${index}].verify_install_timeout`, e.target.value)} fullWidth />
                                    </Box>
                                    <Box mb={2}>
                                        <FormControlLabel
                                            control={<Checkbox checked={command.skip_on_verify_fail || false} onChange={(e) => handleArrayFieldChange(`commands[${index}].skip_on_verify_fail`, e.target.checked)} />}
                                            label="Skip on Verify Fail"
                                        />
                                    </Box>
                                    <Box mb={2}>
                                        <TextField label="Namespace" value={command.namespace || ''} onChange={(e) => handleArrayFieldChange(`commands[${index}].namespace`, e.target.value)} fullWidth />
                                    </Box>
                                    <Box mb={2}>
                                        <TextField label="Command Stream" value={command.command_stream || ''} onChange={(e) => handleArrayFieldChange(`commands[${index}].command_stream`, e.target.value)} fullWidth multiline rows={4} placeholder="Enter each command on a new line" />
                                    </Box>
                                    <Button variant="outlined" color="error" onClick={() => handleArrayRemove('commands', index)}>Remove Command Set</Button>
                                </Box>
                            ))}
                            <Button variant="outlined" color="primary" onClick={() => handleArrayAdd('commands')}>Add Command Set</Button>
                        </Box>
                    </Box>
                );
            case 5:
                return (
                    <Box>
                        <Typography variant="h6">Review & Execute</Typography>
                        <Box sx={{ overflowY: 'auto', maxHeight: '300px', padding: 2, backgroundColor: '#f5f5f5', borderRadius: '4px', border: '1px solid #ddd' }}>
                            <pre>{yaml.dump(config)}</pre>
                        </Box>
                    </Box>
                );
            default:
                return 'Unknown step';
        }
    };

    if (loading) return <CircularProgress />;
    if (error) return <Alert severity="error">{error}</Alert>;

    return (
        <Container maxWidth="lg">
            <Box my={4}>
                <Stepper activeStep={activeStep} alternativeLabel>
                    {steps.map((label) => (
                        <Step key={label}>
                            <StepLabel>{label}</StepLabel>
                        </Step>
                    ))}
                </Stepper>
                <Paper elevation={3} sx={{ padding: 3, marginTop: 2 }}>
                    {renderStepContent(activeStep)}
                    <Box mt={2}>
                        <Button disabled={activeStep === 0} onClick={handleBack} sx={{ marginRight: 1 }}>Back</Button>
                        {activeStep === steps.length - 1 ? (
                            <Button variant="contained" color="primary" onClick={saveConfig}>Save & Finish</Button>
                        ) : (
                            <Button variant="contained" color="primary" onClick={handleNext}>Next</Button>
                        )}
                    </Box>
                    <Box mt={3} display="flex" justifyContent="flex-end" gap={2}>
                        <Button variant="contained" color="primary" onClick={() => streamToTerminal('install')}>
                            Run Install
                        </Button>
                        <Button variant="contained" color="error" onClick={() => streamToTerminal('uninstall')}>
                            Run Uninstall
                        </Button>
                    </Box>
                </Paper>

                <Box mt={3}>
                    <Paper elevation={3} sx={{ padding: 2, backgroundColor: '#222', color: '#eee' }}>
                        <Typography variant="h6">Terminal Output</Typography>
                        <Box sx={{ overflowY: 'auto', height: '300px', padding: 1, backgroundColor: '#000', color: '#00FF00', fontSize: '0.85rem' }}>
                            <pre>{terminalOutput}</pre>
                        </Box>
                    </Paper>
                </Box>
            </Box>
        </Container>
    );
}

export default WizardApp;
