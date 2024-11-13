import React, { useState, useEffect } from 'react';
import axios from 'axios';
import {
    Container, TextField, Checkbox, FormControl, FormControlLabel, FormLabel, Button, Typography, CircularProgress, Alert, Box, Grid, Paper, AppBar, Toolbar, InputAdornment, IconButton
} from '@mui/material';
import SearchIcon from '@mui/icons-material/Search';
import AddIcon from '@mui/icons-material/Add';
import _ from 'lodash';

const BASE_URL = 'http://127.0.0.1:5001';  // Global base URL

function App() {
    const [config, setConfig] = useState({});
    const [filteredConfig, setFilteredConfig] = useState({});
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [searchTerm, setSearchTerm] = useState('');
    const [terminalOutput, setTerminalOutput] = useState('');

    useEffect(() => {
        fetchConfig();
    }, []);

    const fetchConfig = async () => {
        setLoading(true);
        try {
            const response = await axios.get(`${BASE_URL}/config`);
            setConfig(response.data);
            setFilteredConfig(response.data);
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
        setTerminalOutput('');  // Clear previous output
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
                setTerminalOutput(prev => prev + decoder.decode(value));
            }
        } catch (error) {
            console.error(`Error with ${endpoint}:`, error);
            setError(`Error with ${endpoint}`);
        }
    };

    const handleInstall = () => streamToTerminal('install');
    const handleUninstall = () => streamToTerminal('uninstall');

    const handleSearch = (term) => {
        setSearchTerm(term);
        const filterConfig = (obj) => {
            const result = {};
            for (const key in obj) {
                if (typeof obj[key] === 'object' && obj[key] !== null) {
                    const nested = filterConfig(obj[key]);
                    if (Object.keys(nested).length > 0) result[key] = nested;
                } else if (key.toLowerCase().includes(term.toLowerCase())) {
                    result[key] = obj[key];
                }
            }
            return result;
        };
        setFilteredConfig(term ? filterConfig(config) : config);
    };

    const handleChange = (path, value) => {
        setConfig(prevConfig => {
            const newConfig = _.cloneDeep(prevConfig);
            _.set(newConfig, path, value);
            return newConfig;
        });

        // Update filteredConfig to reflect changes in the form
        setFilteredConfig(prevFilteredConfig => {
            const newFilteredConfig = _.cloneDeep(prevFilteredConfig);
            _.set(newFilteredConfig, path, value);
            return newFilteredConfig;
        });
    };

    const handleArrayAdd = (path) => {
        setConfig(prevConfig => {
            const newConfig = _.cloneDeep(prevConfig);
            const array = _.get(newConfig, path, []);
            array.push('');
            _.set(newConfig, path, array);
            return newConfig;
        });

        setFilteredConfig(prevFilteredConfig => {
            const newFilteredConfig = _.cloneDeep(prevFilteredConfig);
            const array = _.get(newFilteredConfig, path, []);
            array.push('');
            _.set(newFilteredConfig, path, array);
            return newFilteredConfig;
        });
    };

    const renderForm = (obj, path = '') => {
        return Object.keys(obj).map(key => {
            const newPath = path ? `${path}.${key}` : key;
            if (typeof obj[key] === 'object' && obj[key] !== null && !Array.isArray(obj[key])) {
                return (
                    <Box key={newPath} mb={3}>
                        <Typography variant="h6">{key}</Typography>
                        {renderForm(obj[key], newPath)}
                    </Box>
                );
            } else if (Array.isArray(obj[key])) {
                return (
                    <FormControl key={newPath} fullWidth margin="normal">
                        <FormLabel>{key}</FormLabel>
                        {obj[key].map((item, index) => (
                            <TextField
                                key={`${newPath}.${index}`}
                                type="text"
                                value={item}
                                onChange={e => handleChange(`${newPath}[${index}]`, e.target.value)}
                                fullWidth
                                margin="normal"
                            />
                        ))}
                        <IconButton onClick={() => handleArrayAdd(newPath)} color="primary">
                            <AddIcon /> Add Item
                        </IconButton>
                    </FormControl>
                );
            } else {
                return (
                    <FormControl key={newPath} fullWidth margin="normal">
                        <FormLabel>{key}</FormLabel>
                        {typeof obj[key] === 'boolean' ? (
                            <FormControlLabel
                                control={
                                    <Checkbox
                                        checked={obj[key]}
                                        onChange={e => handleChange(newPath, e.target.checked)}
                                    />
                                }
                                label={key}
                            />
                        ) : (
                            <TextField
                                type="text"
                                value={obj[key] !== null ? obj[key] : ''}
                                onChange={e => handleChange(newPath, e.target.value)}
                                fullWidth
                            />
                        )}
                    </FormControl>
                );
            }
        });
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
                <Grid item xs={5}>
                    <Box display="flex" flexDirection="column" height="85vh">
                        <TextField
                            placeholder="Search configuration..."
                            value={searchTerm}
                            onChange={e => handleSearch(e.target.value)}
                            fullWidth
                            margin="normal"
                            InputProps={{
                                startAdornment: (
                                    <InputAdornment position="start">
                                        <SearchIcon />
                                    </InputAdornment>
                                ),
                            }}
                        />
                        <Box flexGrow={1} overflow="auto" mt={2}>
                            <form>{renderForm(filteredConfig)}</form>
                        </Box>
                        <Box mt={2} mb={2} textAlign="center">
                            <Button variant="contained" color="primary" onClick={saveConfig} style={{ marginRight: '10px' }}>
                                Save Config
                            </Button>
                            <Button variant="contained" color="secondary" onClick={handleInstall} style={{ marginRight: '10px' }}>
                                Run Install
                            </Button>
                            <Button variant="contained" color="error" onClick={handleUninstall}>
                                Run Uninstall
                            </Button>
                        </Box>
                    </Box>
                </Grid>
                <Grid item xs={7}>
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