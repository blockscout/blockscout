{
    callStack: [{}],

    step(log, db) {
        const error = log.getError();

        if (error !== undefined) {
            this.fault(log, db);
        } else {
            this.success(log, db);
        }
    },

    fault(log, db) {
        if (this.topCall().error === undefined) {
            this.putError(log);
        }
    },

    putError(log) {
        if (this.callStack.length > 1) {
            this.putErrorInTopCall(log);
        } else {
            this.putErrorInBottomCall(log);
        }
    },

    putErrorInTopCall(log) {
        const call = this.callStack.pop();
        this.putErrorInCall(log, call);
        this.pushChildCall(call);
    },

    putErrorInBottomCall(log) {
        const call = this.bottomCall();
        this.putErrorInCall(log, call);
    },

    putErrorInCall(log, call) {
        call.error = log.getError();

        if (call.gasBigInt !== undefined) {
            call.gasUsedBigInt = call.gasBigInt;
        }

        delete call.outputOffset;
        delete call.outputLength;
    },

    topCall() {
        return this.callStack[this.callStack.length - 1];
    },

    bottomCall() {
        return this.callStack[0];
    },

    pushChildCall(childCall) {
        const topCall = this.topCall();

        if (topCall.calls === undefined) {
            topCall.calls = [];
        }

        topCall.calls.push(childCall);
    },

    pushGasToTopCall(log) {
        const topCall = this.topCall();

        if (topCall.gasBigInt === undefined) {
            topCall.gasBigInt = log.getGas();
        }
        topCall.gasUsedBigInt = topCall.gasBigInt - log.getGas() - log.getCost();
    },

    success(log, db) {
        const op = log.op.toString();

        this.beforeOp(log, db);

        switch (op) {
            case 'CREATE':
                this.createOp(log);
                break;
            case 'CREATE2':
                this.create2Op(log);
                break;
            case 'SELFDESTRUCT':
                this.selfDestructOp(log, db);
                break;
            case 'CALL':
            case 'CALLCODE':
            case 'DELEGATECALL':
            case 'STATICCALL':
                this.callOp(log, op);
                break;
            case 'REVERT':
                this.revertOp();
                break;
        }
    },

    beforeOp(log, db) {
        const logDepth = log.getDepth();
        const callStackDepth = this.callStack.length;

        if (logDepth < callStackDepth) {
            const call = this.callStack.pop();

            const ret = log.stack.peek(0);

            if (!ret.equals(0)) {
                if (call.type === 'create' || call.type === 'create2') {
                    call.createdContractAddressHash = toHex(toAddress(ret.toString(16)));
                    call.createdContractCode = toHex(db.getCode(toAddress(ret.toString(16))));
                } else {
                    call.output = toHex(log.memory.slice(call.outputOffset, call.outputOffset + call.outputLength));
                }
            } else if (call.error === undefined) {
                call.error = 'internal failure';
            }

            delete call.outputOffset;
            delete call.outputLength;

            this.pushChildCall(call);
        }
        else {
            this.pushGasToTopCall(log);
        }
    },

    createOp(log) {
        const inputOffset = log.stack.peek(1).valueOf();
        const inputLength = log.stack.peek(2).valueOf();
        const inputEnd = inputOffset + inputLength;
        const stackValue = log.stack.peek(0);

        const call = {
            type: 'create',
            from: toHex(log.contract.getAddress()),
            init: toHex(log.memory.slice(inputOffset, inputEnd)),
            valueBigInt: bigInt(stackValue.toString(10))
        };
        this.callStack.push(call);
    },

    create2Op(log) {
        const inputOffset = log.stack.peek(1).valueOf();
        const inputLength = log.stack.peek(2).valueOf();
        const inputEnd = inputOffset + inputLength;
        const stackValue = log.stack.peek(0);

        const call = {
            type: 'create2',
            from: toHex(log.contract.getAddress()),
            init: toHex(log.memory.slice(inputOffset, inputEnd)),
            valueBigInt: bigInt(stackValue.toString(10))
        };
        this.callStack.push(call);
    },

    selfDestructOp(log, db) {
        const contractAddress = log.contract.getAddress();

        this.pushChildCall({
            type: 'selfdestruct',
            from: toHex(contractAddress),
            to: toHex(toAddress(log.stack.peek(0).toString(16))),
            gasBigInt: log.getGas(),
            gasUsedBigInt: log.getCost(),
            valueBigInt: db.getBalance(contractAddress)
        });
    },

    callOp(log, op) {
        const to = toAddress(log.stack.peek(1).toString(16));

        if (!isPrecompiled(to)) {
            this.callCustomOp(log, op, to);
        }
    },

    callCustomOp(log, op, to) {
        const stackOffset = (op === 'DELEGATECALL' || op === 'STATICCALL' ? 0 : 1);

        const inputOffset = log.stack.peek(2 + stackOffset).valueOf();
        const inputLength = log.stack.peek(3 + stackOffset).valueOf();
        const inputEnd = inputOffset + inputLength;

        const call = {
            type: 'call',
            callType: op.toLowerCase(),
            from: toHex(log.contract.getAddress()),
            to: toHex(to),
            input: toHex(log.memory.slice(inputOffset, inputEnd)),
            outputOffset: log.stack.peek(4 + stackOffset).valueOf(),
            outputLength: log.stack.peek(5 + stackOffset).valueOf()
        };

        switch (op) {
            case 'CALL':
            case 'CALLCODE':
                call.valueBigInt = bigInt(log.stack.peek(2));
                break;
            case 'DELEGATECALL':
                break;
            case 'STATICCALL':
                call.valueBigInt = bigInt.zero;
                break;
            default:
                throw 'Unknown custom call op ' + op;
        }

        this.callStack.push(call);
    },

    revertOp() {
        this.topCall().error = 'execution reverted';
    },

    result(ctx, db) {
        const result = this.ctxToResult(ctx, db);
        const filtered = this.filterNotUndefined(result);
        const callSequence = this.sequence(filtered, [], filtered.valueBigInt, []).callSequence;
        return this.encodeCallSequence(callSequence);
    },

    ctxToResult(ctx, db) {
        var result;

        switch (ctx.type) {
            case 'CALL':
                result = this.ctxToCall(ctx);
                break;
            case 'CREATE':
                result = this.ctxToCreate(ctx, db);
                break;
            case 'CREATE2':
                result = this.ctxToCreate2(ctx, db);
                break;
        }

        return result;
    },

    ctxToCall(ctx) {
        const result = {
            type: 'call',
            callType: 'call',
            from: toHex(ctx.from),
            to: toHex(ctx.to),
            valueBigInt: bigInt(ctx.value.toString(10)),
            gasBigInt: bigInt(ctx.gas),
            gasUsedBigInt: bigInt(ctx.gasUsed),
            input: toHex(ctx.input)
        };

        this.putBottomChildCalls(result);
        this.putErrorOrOutput(result, ctx);

        return result;
    },

    putErrorOrOutput(result, ctx) {
        const error = this.error(ctx);

        if (error !== undefined) {
            result.error = error;
        } else {
            result.output = toHex(ctx.output);
        }
    },

    ctxToCreate(ctx, db) {
        const result = {
            type: 'create',
            from: toHex(ctx.from),
            init: toHex(ctx.input),
            valueBigInt: bigInt(ctx.value.toString(10)),
            gasBigInt: bigInt(ctx.gas),
            gasUsedBigInt: bigInt(ctx.gasUsed)
        };

        this.putBottomChildCalls(result);
        this.putErrorOrCreatedContract(result, ctx, db);

        return result;
    },

    ctxToCreate2(ctx, db) {
        const result = {
            type: 'create2',
            from: toHex(ctx.from),
            init: toHex(ctx.input),
            valueBigInt: bigInt(ctx.value.toString(10)),
            gasBigInt: bigInt(ctx.gas),
            gasUsedBigInt: bigInt(ctx.gasUsed)
        };

        this.putBottomChildCalls(result);
        this.putErrorOrCreatedContract(result, ctx, db);

        return result;
    },

    putBottomChildCalls(result) {
        const bottomCall = this.bottomCall();
        const bottomChildCalls = bottomCall.calls;

        if (bottomChildCalls !== undefined) {
            result.calls = bottomChildCalls;
        }
    },

    putErrorOrCreatedContract(result, ctx, db) {
        const error = this.error(ctx);

        if (error !== undefined) {
            result.error = error
        } else {
            result.createdContractAddressHash = toHex(ctx.to);
            if (toHex(ctx.input) != '0x') {
              result.createdContractCode = toHex(db.getCode(ctx.to));
            } else {
              result.createdContractCode = '0x';
            }
        }
    },

    error(ctx) {
        var error;

        const bottomCall = this.bottomCall();
        const bottomCallError = bottomCall.error;

        if (bottomCallError !== undefined) {
            error = bottomCallError;
        } else {
            const ctxError = ctx.error;

            if (ctxError !== undefined) {
                error = ctxError;
            }
        }

        return error;
    },

    filterNotUndefined(call) {
        for (var key in call) {
            if (call[key] === undefined) {
                delete call[key];
            }
        }

        if (call.calls !== undefined) {
            for (var i = 0; i < call.calls.length; i++) {
                call.calls[i] = this.filterNotUndefined(call.calls[i]);
            }
        }

        return call;
    },

    sequence(call, callSequence, availableValueBigInt, traceAddress) {
        const subcalls = call.calls;
        delete call.calls;

        call.traceAddress = traceAddress;

        if (call.type === 'call' && call.callType === 'delegatecall') {
            call.valueBigInt = availableValueBigInt;
        }

        var newCallSequence = callSequence.concat([call]);

        if (subcalls !== undefined) {
            for (var i = 0; i < subcalls.length; i++) {
                const nestedSequenced = this.sequence(
                    subcalls[i],
                    newCallSequence,
                    call.valueBigInt,
                    traceAddress.concat([i])
                );
                newCallSequence = nestedSequenced.callSequence;
            }
        }

        return {
            callSequence: newCallSequence
        };
    },

    encodeCallSequence(calls) {
        for (var i = 0; i < calls.length; i++) {
            this.encodeCall(calls[i]);
        }

        return calls;
    },

    encodeCall(call) {
        this.putValue(call);
        this.putGas(call);
        this.putGasUsed(call);

        return call;
    },

    putValue(call) {
        const valueBigInt = call.valueBigInt;
        delete call.valueBigInt;

        call.value = '0x' + valueBigInt.toString(16);
    },

    putGas(call) {

        if (call.gasBigInt === undefined) {
            call.gas = '0x0';
        } else {
            call.gas = '0x' + call.gasBigInt.toString(16);
        }

        delete call.gasBigInt;

    },

    putGasUsed(call) {

        if (call.gasUsedBigInt === undefined) {
            call.gasUsed = '0x0';
        } else {
            call.gasUsed = '0x' + call.gasUsedBigInt.toString(16);
        }

        delete call.gasUsedBigInt;
    }
}
