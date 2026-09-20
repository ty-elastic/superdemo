import * as React from 'react';
import axios from "axios";

import MonkeyState from './MonkeyState'
import FormControl from '@mui/material/FormControl';
import InputLabel from '@mui/material/InputLabel';
import Select from '@mui/material/Select';
import MenuItem from '@mui/material/MenuItem';
import Grid from '@mui/material/Grid2';
import Button from '@mui/material/Button';
import Checkbox from '@mui/material/Checkbox';
import Box from '@mui/material/Box';
import FormControlLabel from '@mui/material/FormControlLabel';
import FormGroup from '@mui/material/FormGroup';

class ErrorLatency extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            latency_on: false,
            latency_action: 'any',
            latency_oneshot: true
        };

        this.monkeyState = new MonkeyState(this, 'latency_per_action');

        this.handleInputChange = this.handleInputChange.bind(this);
        this.handleSubmit = this.handleSubmit.bind(this);
    }

    handleInputChange(event) {
        const target = event.target;
        const value = target.type === 'checkbox' ? target.checked : target.value;
        const name = target.name;

        this.setState({
            [name]: value
        });
    }

    async handleSubmit(event) {
        event.preventDefault();

        try {
            if (this.state.latency_on === false) {
                await axios.delete(`/monkey/latency`);
            } else {
                await axios.post(`/monkey/latency/800`,
                    null,
                    {
                        params: {
                            'latency_action': (this.state.latency_action === 'any') ? null : this.state.latency_action,
                            'latency_oneshot': this.state.latency_oneshot
                        }
                    }
                );
            }
            this.monkeyState.fetchData();
        } catch (err) {
            console.log(err.message)
        }
    }

    render() {
        return (
            <form name="latency" onSubmit={this.handleSubmit}>
                <Grid container spacing={2}>
                    <FormGroup>
                        <FormControlLabel control={<Checkbox
                            name='latency_on'
                            checked={this.state.latency_on}
                            onChange={this.handleInputChange}
                            inputProps={{ 'aria-label': 'controlled' }}
                        />} label="Generate latency" />
                    </FormGroup>
                    <FormGroup>
                        <FormControlLabel control={<Checkbox
                            name='latency_oneshot'
                            checked={this.state.latency_oneshot}
                            onChange={this.handleInputChange}
                            inputProps={{ 'aria-label': 'controlled' }}
                        />} label="Oneshot" />
                    </FormGroup>
                    {/* <FormControl>
                        <InputLabel id="label_action">Action</InputLabel>
                        <Select
                            labelId="label_action"
                            name="latency_action"
                            value={this.state.latency_action}
                            label="Action"
                            onChange={this.handleInputChange}
                        >
                            <MenuItem value="any">Any</MenuItem>
                            <MenuItem value="buy">Buy</MenuItem>
                            <MenuItem value="sell">Sell</MenuItem>
                            <MenuItem value="hold">Hold</MenuItem>
                        </Select>
                    </FormControl> */}
                    <Box width="100%"><Button variant="contained" data-transaction-name="ErrorLatency" type="submit">Submit</Button></Box>
                    {this.monkeyState.render()}
                </Grid>
            </form>
        );
    }
}

export default ErrorLatency;