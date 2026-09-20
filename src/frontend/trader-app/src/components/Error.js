import React, { useState, useEffect } from 'react';

import ErrorLatency from './ErrorLatency'
import Page from './Page'

import ErrorModel from './ErrorModel'
import ErrorDb from './ErrorDb'
import ErrorReset from './ErrorReset'
import ErrorLocal from './ErrorLocal'
import ErrorGc from './ErrorGc'
import ErrorSlowQuery from './ErrorSlowQuery'

const sections = [
  { label: 'Reset', desc: 'Reset error conditions', element: ErrorReset }, 
  { label: 'Browser', desc: 'Browser (Javascript) error', element: ErrorLocal },
  { label: 'Model', desc: 'Model error', element: ErrorModel },
  { label: 'DB', desc: 'Database error', element: ErrorDb },
  { label: 'Latency', desc: 'Latency', element: ErrorLatency },
  { label: 'GC', desc: 'Garbage Collector', element: ErrorGc },
  { label: 'SlowQuery', desc: 'Slow Query', element: ErrorSlowQuery }
];

class Error extends React.Component {
    constructor(props) {
        super(props);
        this.handleBrowserException = this.handleBrowserException.bind(this);
    }

    handleBrowserException(event) {
        throw new Error('Intentional Exception!');
    }
    render() {
        return (
          <Page sections={sections}></Page>
        );
      }
}

export default Error;
