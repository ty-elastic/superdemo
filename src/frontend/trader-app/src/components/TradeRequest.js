import * as React from 'react';
import axios from "axios";

import { CircularProgress } from '@mui/material';
import MonkeyState from './MonkeyState'
import FormControl from '@mui/material/FormControl';
import InputLabel from '@mui/material/InputLabel';
import FormLabel from '@mui/material/FormLabel';
import Select from '@mui/material/Select';
import MenuItem from '@mui/material/MenuItem';
import Grid from '@mui/material/Grid2';
import Button from '@mui/material/Button';
import Slider from '@mui/material/Slider';
import Typography from '@mui/material/Typography';
import TextField from '@mui/material/TextField';
import Box from '@mui/material/Box';

class TradeRequest extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            symbol: 'OELK',
            day_of_week: 'M',
            customer_id: "tb93",
            loading: false,
            result: null
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
        
        this.setState({['loading']: true});
        this.setState({['error']: null});
        try {
            const response = await axios.post("/trader/trade/request", {
                    'symbol': this.state.symbol,
                    'day_of_week': this.state.day_of_week,
                    'customer_id': this.state.customer_id,
                    'data_source': 'customer'
            });
            if (response.status != 200) {
                throw new Error(response.status);
            } else{
                this.setState({['result']: "successfully completed trade request"});
            }
        } catch (err) {
            console.log(err.message)
            this.setState({['result']: `unable to complete trade request! status: ${err.message}`});
        }
        finally {
            this.setState({['loading']: false});
        }
    }


    render() {
        return (
            <form onSubmit={this.handleSubmit}>
                <Grid container spacing={2}>

                    <TextField
                        id="outlined-error"
                        name="symbol"
                        value={this.state.symbol}
                        onChange={this.handleInputChange}
                        label="Symbol"
                    />
                    <FormControl>
                        <InputLabel id="label_dow">Day of Week</InputLabel>
                        <Select
                            labelId="label_dow"
                            name="day_of_week"
                            value={this.state.day_of_week}
                            label="Day of Week"
                            onChange={this.handleInputChange}
                        >
                            <MenuItem value="M">Monday</MenuItem>
                            <MenuItem value="Tu">Tuesday</MenuItem>
                            <MenuItem value="W">Wednesday</MenuItem>
                            <MenuItem value="Th">Thursday</MenuItem>
                            <MenuItem value="F">Friday</MenuItem>
                        </Select>
                    </FormControl>
                    <TextField
                        id="outlined-error"
                        name="customer_id"
                        value={this.state.customer_id}
                        onChange={this.handleInputChange}
                        label="Customer ID"
                    />

                    <div>
                        {this.state.loading ? (
                        <CircularProgress />
                        ) : (
                        <Box width="100%"><Button variant="contained" data-transaction-name="TradeRequest" type="submit">Submit</Button></Box>
                        )}
                        {this.state.result ? (<p>Result: {this.state.result}</p>) : (<p></p>)}
                    </div>
                </Grid>
            </form>
        );
    }
}

export default TradeRequest;