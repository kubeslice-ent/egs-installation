// src/components/GlobalSettings.js
import React from 'react';
import { TextField, Checkbox, FormControlLabel, Box, Typography } from '@mui/material';

function GlobalSettings({ config, onChange }) {
    return (
        <Box>
            <Typography variant="h6" gutterBottom>Global Settings</Typography>
            <TextField
                label="Base Path"
                value={config.base_path || ''}
                onChange={(e) => onChange('base_path', e.target.value)}
                fullWidth
                margin="normal"
            />
            <FormControlLabel
                control={
                    <Checkbox
                        checked={config.precheck || false}
                        onChange={(e) => onChange('precheck', e.target.checked)}
                    />
                }
                label="Run Precheck"
            />
            <FormControlLabel
                control={
                    <Checkbox
                        checked={config.verify_install || false}
                        onChange={(e) => onChange('verify_install', e.target.checked)}
                    />
                }
                label="Verify Install"
            />
            <TextField
                label="Global Helm Repo URL"
                value={config.global_helm_repo_url || ''}
                onChange={(e) => onChange('global_helm_repo_url', e.target.value)}
                fullWidth
                margin="normal"
            />
            {/* Add more fields as needed based on the global settings in your config */}
        </Box>
    );
}

export default GlobalSettings;