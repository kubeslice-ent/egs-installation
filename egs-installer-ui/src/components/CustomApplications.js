// src/components/CustomApplications.js
import React, { useState } from 'react';
import { Box, Typography, Button, TextField, IconButton } from '@mui/material';
import AddIcon from '@mui/icons-material/Add';
import RemoveIcon from '@mui/icons-material/Remove';

function CustomApplications({ config, onChange }) {
    const [customApps, setCustomApps] = useState(config.manifests || []);

    const addCustomApp = () => {
        const newApp = { name: '', namespace: '', manifest_url: '' };
        const updatedApps = [...customApps, newApp];
        setCustomApps(updatedApps);
        onChange('manifests', updatedApps);
    };

    const removeCustomApp = (index) => {
        const updatedApps = customApps.filter((_, i) => i !== index);
        setCustomApps(updatedApps);
        onChange('manifests', updatedApps);
    };

    const handleCustomAppChange = (index, field, value) => {
        const updatedApps = customApps.map((app, i) =>
            i === index ? { ...app, [field]: value } : app
        );
        setCustomApps(updatedApps);
        onChange('manifests', updatedApps);
    };

    return (
        <Box>
            <Typography variant="h6" gutterBottom>Custom Applications</Typography>
            {customApps.map((app, index) => (
                <Box key={index} sx={{ marginBottom: 3, padding: 2, border: '1px solid #ddd', borderRadius: '8px' }}>
                    <Typography variant="subtitle1">Custom Application {index + 1}</Typography>
                    <TextField
                        label="Application Name"
                        value={app.name || ''}
                        onChange={(e) => handleCustomAppChange(index, 'name', e.target.value)}
                        fullWidth
                        margin="normal"
                    />
                    <TextField
                        label="Namespace"
                        value={app.namespace || ''}
                        onChange={(e) => handleCustomAppChange(index, 'namespace', e.target.value)}
                        fullWidth
                        margin="normal"
                    />
                    <TextField
                        label="Manifest URL"
                        value={app.manifest_url || ''}
                        onChange={(e) => handleCustomAppChange(index, 'manifest_url', e.target.value)}
                        fullWidth
                        margin="normal"
                    />
                    <Box sx={{ display: 'flex', justifyContent: 'flex-end', marginTop: 1 }}>
                        <IconButton onClick={() => removeCustomApp(index)} color="error">
                            <RemoveIcon />
                        </IconButton>
                    </Box>
                </Box>
            ))}
            <Button onClick={addCustomApp} variant="contained" startIcon={<AddIcon />} sx={{ marginTop: 2 }}>
                Add Custom Application
            </Button>
        </Box>
    );
}

export default CustomApplications;