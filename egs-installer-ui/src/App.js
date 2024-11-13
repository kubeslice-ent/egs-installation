// src/App.js
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import {
    Container, Typography, Button, CircularProgress, Alert, Box, Grid, Paper, AppBar, Toolbar, Stepper, Step, StepLabel
} from '@mui/material';
import GlobalSettings from './components/GlobalSettings';
import ControllerInstallation from './components/ControllerInstallation';
import UIInstallation from './components/UIInstallation';
import WorkerInstallation from './components/WorkerInstallation';
import AdditionalApplications from './components/AdditionalApplications';
import CustomApplications from './components/CustomApplications';
import CommandExecution from './components/CommandExecution';

const BASE_URL = 'http://127.0.0.1:5001';

const steps = [
    'Global Settings',
    'Controller Installation',
    'UI Installation',
    'Worker Installation',
    'Additional Applications',
    'Custom Applications',
    'Command Execution'
];

function App() {
    const [activeStep, setActiveStep] = useState(0);
    const [config, setConfig] = useState({});
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [terminalOutput, setTerminalOutput] = useState('');

    useEffect(() => {
        axios.get(`${BASE_URL}/config`)
            .then(response => {
                setConfig(response.data);
                setLoading(false);
            })
            .catch(error => {
                console.error('Error fetching config:', error);
                setError('Error fetching config');
                setLoading(false);
            });
    }, []);

    const handleNext = () => setActiveStep((prev) => prev + 1);
    const handleBack = () => setActiveStep((prev) => prev - 1);
    const handleReset = () => setActiveStep(0);

    const handleChange = (path, value) => {
        setConfig(prevConfig => {
            const newConfig = { ...prevConfig };
            const keys = path.split('.');
            let obj = newConfig;
            for (let i = 0; i < keys.length - 1; i++) {
                if (!obj[keys[i]]) obj[keys[i]] = {};
                obj = obj[keys[i]];
            }
            obj[keys[keys.length - 1]] = value;
            return newConfig;
        });
    };

    const handleSubmit = () => {
        axios.post(`${BASE_URL}/config`, config)
            .then(() => alert('Config updated successfully'))
            .catch(error => {
                console.error('Error updating config:', error);
                setError('Error updating config');
            });
    };

    const handleInstall = () => {
        setTerminalOutput("");  
        fetch(`${BASE_URL}/install`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        })
        .then(response => {
            const reader = response.body.getReader();
            const decoder = new TextDecoder("utf-8");
            const readStream = () => {
                reader.read().then(({ done, value }) => {
                    if (done) {
                        setTerminalOutput(prev => prev + "\nInstallation complete.");
                        return;
                    }
                    setTerminalOutput(prev => prev + decoder.decode(value));
                    readStream();
                });
            };
            readStream();
        })
        .catch(error => {
            console.error('Error starting installation:', error);
            setError('Error starting installation');
        });
    };

    const handleUninstall = () => {
        setTerminalOutput("");  
        fetch(`${BASE_URL}/uninstall`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        })
        .then(response => {
            const reader = response.body.getReader();
            const decoder = new TextDecoder("utf-8");
            const readStream = () => {
                reader.read().then(({ done, value }) => {
                    if (done) {
                        setTerminalOutput(prev => prev + "\nUninstallation complete.");
                        return;
                    }
                    setTerminalOutput(prev => prev + decoder.decode(value));
                    readStream();
                });
            };
            readStream();
        })
        .catch(error => {
            console.error('Error starting uninstallation:', error);
            setError('Error starting uninstallation');
        });
    };

    const getStepContent = (step) => {
        switch (step) {
            case 0:
                return <GlobalSettings config={config} onChange={handleChange} />;
            case 1:
                return <ControllerInstallation config={config} onChange={handleChange} />;
            case 2:
                return <UIInstallation config={config} onChange={handleChange} />;
            case 3:
                return <WorkerInstallation config={config} onChange={handleChange} />;
            case 4:
                return <AdditionalApplications config={config} onChange={handleChange} />;
            case 5:
                return <CustomApplications config={config} onChange={handleChange} />;
            case 6:
                return <CommandExecution config={config} onChange={handleChange} />;
            default:
                return <Typography>Unknown step</Typography>;
        }
    };

    if (loading) return <CircularProgress />;
    if (error) return <Alert severity="error">{error}</Alert>;

    return (
        <Container maxWidth={false} sx={{ width: '100%', padding: 0 }}>
            <AppBar position="static">
                <Toolbar>
                    <Typography variant="h5">EGS Installer</Typography>
                </Toolbar>
            </AppBar>
            <Grid container spacing={2} sx={{ padding: '20px' }}>
                <Grid item xs={7}>
                    <Box display="flex" flexDirection="column" height="85vh">
                        <Stepper activeStep={activeStep} alternativeLabel>
                            {steps.map((label) => (
                                <Step key={label}>
                                    <StepLabel>{label}</StepLabel>
                                </Step>
                            ))}
                        </Stepper>
                        <Box flexGrow={1} overflow="auto" mt={2}>
                            {getStepContent(activeStep)}
                        </Box>
                        <Box mt={2} textAlign="center">
                            <Button onClick={handleBack} disabled={activeStep === 0}>Back</Button>
                            {activeStep < steps.length - 1 ? (
                                <Button onClick={handleNext} variant="contained">Next</Button>
                            ) : (
                                <Button variant="contained" onClick={handleSubmit}>Save Config</Button>
                            )}
                            <Button variant="contained" color="secondary" onClick={handleInstall} style={{ marginLeft: '10px' }}>
                                Run Install
                            </Button>
                            <Button variant="contained" color="error" onClick={handleUninstall} style={{ marginLeft: '10px' }}>
                                Run Uninstall
                            </Button>
                        </Box>
                    </Box>
                </Grid>
                <Grid item xs={5}>
                    <Paper elevation={3} sx={{ height: '85vh', padding: '16px', overflowY: 'auto', backgroundColor: '#222', color: '#eee' }}>
                        <Typography variant="h6" gutterBottom>Terminal Output</Typography>
                        <pre>{terminalOutput}</pre>
                    </Paper>
                </Grid>
            </Grid>
        </Container>
    );
}

export default App;