// src/components/UIInstallation.js
import React from 'react';
import { TextField, Box, Typography } from '@mui/material';

function UIInstallation({ config, onChange }) {
    const uiConfig = config.kubeslice_ui_egs || {};

    return (
        <Box>
            <Typography variant="h6" gutterBottom>UI Installation</Typography>
            <TextField
                label="Namespace"
                value={uiConfig.namespace || ''}
                onChange={(e) => onChange('kubeslice_ui_egs.namespace', e.target.value)}
                fullWidth
                margin="normal"
            />
            <TextField
                label="Release Name"
                value={uiConfig.release_name || ''}
                onChange={(e) => onChange('kubeslice_ui_egs.release_name', e.target.value)}
                fullWidth
                margin="normal"
            />
            <TextField
                label="Chart Version"
                value={uiConfig.chart_version || ''}
                onChange={(e) => onChange('kubeslice_ui_egs.chart_version', e.target.value)}
                fullWidth
                margin="normal"
            />
            <TextField
                label="Helm Repo URL"
                value={uiConfig.helm_repo_url || ''}
                onChange={(e) => onChange('kubeslice_ui_egs.helm_repo_url', e.target.value)}
                fullWidth
                margin="normal"
            />
            {/* Add more fields as needed based on the UI settings in your config */}
        </Box>
    );
}

export default UIInstallation;