// src/components/ControllerInstallation.js
import React from 'react';
import { TextField, Box, Typography } from '@mui/material';

function ControllerInstallation({ config, onChange }) {
    const controllerConfig = config.kubeslice_controller_egs || {};

    return (
        <Box>
            <Typography variant="h6" gutterBottom>Controller Installation</Typography>
            <TextField
                label="Namespace"
                value={controllerConfig.namespace || ''}
                onChange={(e) => onChange('kubeslice_controller_egs.namespace', e.target.value)}
                fullWidth
                margin="normal"
            />
            <TextField
                label="Release Name"
                value={controllerConfig.release_name || ''}
                onChange={(e) => onChange('kubeslice_controller_egs.release_name', e.target.value)}
                fullWidth
                margin="normal"
            />
            <TextField
                label="Chart Version"
                value={controllerConfig.chart_version || ''}
                onChange={(e) => onChange('kubeslice_controller_egs.chart_version', e.target.value)}
                fullWidth
                margin="normal"
            />
            <TextField
                label="Helm Repo URL"
                value={controllerConfig.helm_repo_url || ''}
                onChange={(e) => onChange('kubeslice_controller_egs.helm_repo_url', e.target.value)}
                fullWidth
                margin="normal"
            />
            {/* Add more fields as needed based on the controller settings in your config */}
        </Box>
    );
}

export default ControllerInstallation;