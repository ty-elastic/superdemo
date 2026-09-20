import * as React from 'react';
import axios from "axios";

import { CircularProgress } from '@mui/material';
import Autocomplete from '@mui/material/Autocomplete';
import Grid from '@mui/material/Grid2';
import Button from '@mui/material/Button';
import Typography from '@mui/material/Typography';
import TextField from '@mui/material/TextField';
import Slider from '@mui/material/Slider';
import Box from '@mui/material/Box';
import FormGroup from '@mui/material/FormGroup';
import FormControlLabel from '@mui/material/FormControlLabel';
import Checkbox from '@mui/material/Checkbox';

class Train extends React.Component {

    constructor(props) {
        super(props);

        this.options = {}
        this.options.day_of_week = [
            { value: 'M', label: 'Monday' },
            { value: 'Tu', label: 'Tuesday' },
            { value: 'W', label: 'Wednesday' },
            { value: 'Th', label: 'Thursday' },
            { value: 'F', label: 'Friday' },
        ];

        this.options.action = [
            { value: 'buy', label: 'Buy' },
            { value: 'sell', label: 'Sell' },
            { value: 'hold', label: 'Hold' }
        ];

        this.options.symbol = [
            { value: 'ZVZZT', label: 'ZVZZT' },
            { value: 'ZALM', label: 'ZALM' },
            { value: 'ZYX', label: 'ZYX' },
            { value: 'CBAZ', label: 'CBAZ' },
            { value: 'BAA', label: 'BAA' },
            { value: 'OELK', label: 'OELK' }
        ];

        this.state = {
            day_of_week: this.options.day_of_week,
            symbol: this.options.symbol,
            action: this.options.action,
            shares: [10, 700],
            share_price: [50, 75],
            classification: 'fraud',
            data_source: 'training',
            loading: false,
            shares_enabled: false,
            share_price_enabled: false
        };

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
            let params = {}

            if (this.state.day_of_week.length > 0) {
                params.day_of_week = this.state.day_of_week.map(item => item.value)
            }
            if (this.state.symbol.length > 0) {
                params.symbol = this.state.symbol.map(item => item.value)
            }
            if (this.state.action.length > 0) {
                params.action = this.state.action.map(item => item.value)
            }
            if (this.state.shares_enabled == true) {
                params.shares_min = this.state.shares[0]
                params.shares_max = this.state.shares[1]
            }
            if (this.state.share_price_enabled == true) {
                params.share_price_min = this.state.share_price[0]
                params.share_price_max = this.state.share_price[1]
            }
            if (this.state.data_source.length > 0) {
                params.data_source = this.state.data_source
            }

            console.log(this.state)
            console.log(params)

            this.setState({['loading']: true});
            await axios.post(`/monkey/train/${this.state.classification}`, params, { timeout: 300000 })
            this.setState({['loading']: false});
        } catch (err) {
            console.log(err.message)
        }
    }

    render() {
        return (
            <form onSubmit={this.handleSubmit}>
                <Grid container spacing={2}>

                    <Autocomplete
                        multiple
                        options={this.options.day_of_week}
                        name="day_of_week"
                        value={this.state.day_of_week}
                        onChange={(event, newValue) => {this.setState({['day_of_week']: newValue})}}
                        renderInput={(params) => (
                        <TextField
                            {...params}
                            variant="standard"
                            label="Day of Week"
                        />
                        )}
                    />

                    <Autocomplete
                        multiple
                        options={this.options.symbol}
                        name="symbol"
                        value={this.state.symbol}
                        onChange={(event, newValue) => {this.setState({['symbol']: newValue});}}
                        renderInput={(params) => (
                        <TextField
                            {...params}
                            variant="standard"
                            label="Symbol"
                        />
                        )}
                    />

                    <Autocomplete
                        multiple
                        options={this.options.action}
                        name="action"
                        value={this.state.action}
                        onChange={(event, newValue) => {this.setState({['action']: newValue});}}
                        renderInput={(params) => (
                        <TextField
                            {...params}
                            variant="standard"
                            label="Action"
                        />
                        )}
                    />

                    <Grid size={4}>
                        <FormGroup>
                            <FormControlLabel control={<Checkbox
                                name='shares_enabled'
                                checked={this.state.shares_enabled}
                                onChange={this.handleInputChange}
                                inputProps={{ 'aria-label': 'controlled' }}
                            />} label="Shares" />
                            <Slider onChange={this.handleInputChange}
                                name="shares"
                                getAriaValueText={() => this.state.shares}
                                valueLabelDisplay="on"
                                shiftStep={30}
                                step={10}
                                marks
                                min={0}
                                max={1000}
                                value={this.state.shares}
                                disabled={!this.state.shares_enabled}
                            />
                        </FormGroup>
                    </Grid>

                    <Grid size={4}>
                        <FormGroup>
                            <FormControlLabel control={<Checkbox
                                name='share_price_enabled'
                                checked={this.state.share_price_enabled}
                                onChange={this.handleInputChange}
                                inputProps={{ 'aria-label': 'controlled' }}
                            />} label="Share Price" />
                            <Slider onChange={this.handleInputChange}
                                name="shares"
                                getAriaValueText={() => this.state.share_price}
                                valueLabelDisplay="on"
                                shiftStep={30}
                                step={10}
                                marks
                                min={0}
                                max={100}
                                value={this.state.share_price}
                                disabled={!this.state.share_price_enabled}
                            />
                        </FormGroup>
                    </Grid>

                    <TextField
                        id="outlined-error"
                        name="classification"
                        value={this.state.classification}
                        onChange={this.handleInputChange}
                        label="Classification"
                    />
                    <TextField
                        id="outlined-error"
                        name="data_source"
                        value={this.state.data_source}
                        onChange={this.handleInputChange}
                        label="Data Source"
                    />

                    <div>
                        {this.state.loading ? (
                        <CircularProgress />
                        ) : (
                        <Box width="100%"><Button variant="contained" data-transaction-name="Train" type="submit">Submit</Button></Box>
                        )}
                    </div>

                </Grid>
            </form >

        );
    }
}

export default Train;