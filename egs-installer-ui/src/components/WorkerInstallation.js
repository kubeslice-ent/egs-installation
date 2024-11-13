// src/components/WorkerInstallation.js
import React, { useState } from 'react';
import { Box, Typography, Button, TextField, IconButton } from '@mui/material';
import AddIcon from '@mui/icons-material/Add';
import RemoveIcon from '@mui/icons-material/Remove';

function WorkerInstallation({ config, onChange }) {
    const [workers, setWorkers] = useState(config.kubeslice_worker_egs || []);

    const addWorker = () => {
        const newWorker = { name: '', namespace: '', release_name: '', chart_version: '', helm_repo_url: '' };
        const updatedWorkers = [...workers, newWorker];
        setWorkers(updatedWorkers);
        onChange('kubeslice_worker_egs', updatedWorkers);
    };

    const removeWorker = (index) => {
        const updatedWorkers = workers.filter((_, i) => i !== index);
        setWorkers(updatedWorkers);
        onChange('kubeslice_worker_egs', updatedWorkers);
    };

    const handleWorkerChange = (index, field, value) => {
        const updatedWorkers = workers.map((worker, i) =>
            i === index ? { ...worker, [field]: value } : worker
        );
        setWorkers(updatedWorkers);
        onChange('kubeslice_worker_egs', updatedWorkers);
    };

    return (
        <Box>
            <Typography variant="h6" gutterBottom>Worker Installation</Typography>
            {workers.map((worker, index) => (
                <Box key={index} sx={{ marginBottom: 3, padding: 2, border: '1px solid #ddd', borderRadius: '8px' }}>
                    <Typography variant="subtitle1">Worker {index + 1}</Typography>
                    <TextField
                        label="Worker Name"
                        value={worker.name || ''}
                        onChange={(e) => handleWorkerChange(index, 'name', e.target.value)}
                        fullWidth
                        margin="normal"
                    />
                    <TextField
                        label="Namespace"
                        value={worker.namespace || ''}
                        onChange={(e) => handleWorkerChange(index, 'namespace', e.target.value)}
                        fullWidth
                        margin="normal"
                    />
                    <TextField
                        label="Release Name"
                        value={worker.release_name || ''}
                        onChange={(e) => handleWorkerChange(index, 'release_name', e.target.value)}
                        fullWidth
                        margin="normal"
                    />
                    <TextField
                        label="Chart Version"
                        value={worker.chart_version || ''}
                        onChange={(e) => handleWorkerChange(index, 'chart_version', e.target.value)}
                        fullWidth
                        margin="normal"
                    />
                    <TextField
                        label="Helm Repo URL"
                        value={worker.helm_repo_url || ''}
                        onChange={(e) => handleWorkerChange(index, 'helm_repo_url', e.target.value)}
                        fullWidth
                        margin="normal"
                    />
                    <Box sx={{ display: 'flex', justifyContent: 'flex-end', marginTop: 1 }}>
                        <IconButton onClick={() => removeWorker(index)} color="error">
                            <RemoveIcon />
                        </IconButton>
                    </Box>
                </Box>
            ))}
            <Button onClick={addWorker} variant="contained" startIcon={<AddIcon />} sx={{ marginTop: 2 }}>
                Add Worker
            </Button>
        </Box>
    );
}

export default WorkerInstallation;