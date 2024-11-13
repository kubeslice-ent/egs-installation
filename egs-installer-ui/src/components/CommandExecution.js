// src/components/CommandExecution.js
import React, { useState } from 'react';
import { Box, Typography, Button, TextField, IconButton } from '@mui/material';
import AddIcon from '@mui/icons-material/Add';
import RemoveIcon from '@mui/icons-material/Remove';

function CommandExecution({ config, onChange }) {
    const [commands, setCommands] = useState(config.run_commands || []);

    const addCommand = () => {
        const newCommand = { name: '', command: '' };
        const updatedCommands = [...commands, newCommand];
        setCommands(updatedCommands);
        onChange('run_commands', updatedCommands);
    };

    const removeCommand = (index) => {
        const updatedCommands = commands.filter((_, i) => i !== index);
        setCommands(updatedCommands);
        onChange('run_commands', updatedCommands);
    };

    const handleCommandChange = (index, field, value) => {
        const updatedCommands = commands.map((cmd, i) =>
            i === index ? { ...cmd, [field]: value } : cmd
        );
        setCommands(updatedCommands);
        onChange('run_commands', updatedCommands);
    };

    return (
        <Box>
            <Typography variant="h6" gutterBottom>Command Execution</Typography>
            {commands.map((cmd, index) => (
                <Box key={index} sx={{ marginBottom: 3, padding: 2, border: '1px solid #ddd', borderRadius: '8px' }}>
                    <Typography variant="subtitle1">Command {index + 1}</Typography>
                    <TextField
                        label="Command Name"
                        value={cmd.name || ''}
                        onChange={(e) => handleCommandChange(index, 'name', e.target.value)}
                        fullWidth
                        margin="normal"
                    />
                    <TextField
                        label="Command"
                        value={cmd.command || ''}
                        onChange={(e) => handleCommandChange(index, 'command', e.target.value)}
                        fullWidth
                        margin="normal"
                    />
                    <Box sx={{ display: 'flex', justifyContent: 'flex-end', marginTop: 1 }}>
                        <IconButton onClick={() => removeCommand(index)} color="error">
                            <RemoveIcon />
                        </IconButton>
                    </Box>
                </Box>
            ))}
            <Button onClick={addCommand} variant="contained" startIcon={<AddIcon />} sx={{ marginTop: 2 }}>
                Add Command
            </Button>
        </Box>
    );
}

export default CommandExecution;