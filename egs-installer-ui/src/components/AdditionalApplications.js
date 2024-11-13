// src/components/AdditionalApplications.js
import React, { useState } from 'react';
import { Box, Typography, Button, TextField, IconButton } from '@mui/material';
import AddIcon from '@mui/icons-material/Add';
import RemoveIcon from '@mui/icons-material/Remove';

function AdditionalApplications({ config, onChange }) {
    const [applications, setApplications] = useState(config.additional_apps || []);

    const addApplication = () => {
        const newApp = { name: '', chart_version: '', helm_repo_url: '' };
        const updatedApps = [...applications, newApp];
        setApplications(updatedApps);
        onChange('additional_apps', updatedApps);
    };

    const removeApplication = (index) => {
        const updatedApps = applications.filter((_, i) => i !== index);
        setApplications(updatedApps);
        onChange('additional_apps', updatedApps);
    };

    const handleApplicationChange = (index, field, value) => {
        const updatedApps = applications.map((app, i) =>
            i === index ? { ...app, [field]: value } : app
        );
        setApplications(updatedApps);
        onChange('additional_apps', updatedApps);
    };

    return (
        <Box>
            <Typography variant="h6" gutterBottom>Additional Applications</Typography>
            {applications.map((app, index) => (
                <Box key={index} sx={{ marginBottom: 3, padding: 2, border: '1px solid #ddd', borderRadius: '8px' }}>
                    <Typography variant="subtitle1">Application {index + 1}</Typography>
                    <TextField
                        label="Application Name"
                        value={app.name || ''}
                        onChange={(e) => handleApplicationChange(index, 'name', e.target.value)}
                        fullWidth
                        margin="normal"
                    />
                    <TextField
                        label="Chart Version"
                        value={app.chart_version || ''}
                        onChange={(e) => handleApplicationChange(index, 'chart_version', e.target.value)}
                        fullWidth
                        margin="normal"
                    />
                    <TextField
                        label="Helm Repo URL"
                        value={app.helm_repo_url || ''}
                        onChange={(e) => handleApplicationChange(index, 'helm_repo_url', e.target.value)}
                        fullWidth
                        margin="normal"
                    />
                    <Box sx={{ display: 'flex', justifyContent: 'flex-end', marginTop: 1 }}>
                        <IconButton onClick={() => removeApplication(index)} color="error">
                            <RemoveIcon />
                        </IconButton>
                    </Box>
                </Box>
            ))}
            <Button onClick={addApplication} variant="contained" startIcon={<AddIcon />} sx={{ marginTop: 2 }}>
                Add Application
            </Button>
        </Box>
    );
}

export default AdditionalApplications;