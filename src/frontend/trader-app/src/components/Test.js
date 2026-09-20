import React, { useState, useEffect } from 'react';
import Page from './Page'
import TestFlags from './TestFlags'
import TestReset from './TestReset'

const sections = [
    { label: 'Reset', desc: 'Reset test conditions', element: TestReset },
    { label: 'Flags', desc: 'Flags', element: TestFlags },
];

class Test extends React.Component {
    render() {
        return (
            <Page sections={sections}></Page>
        );
    }
}

export default Test;