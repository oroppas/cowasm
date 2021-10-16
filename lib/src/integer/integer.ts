import wasmImport, { WasmInstance } from "../wasm";

// @ts-ignore -- typescript doesn't have FinalizationRegistry
const registry = new FinalizationRegistry((handle) => {
  // console.log(`Freeing memory for ${handle}`);
  wasm?.exports.freeInteger(handle);
});

export let wasm: WasmInstance | undefined = undefined;

export async function init(): Promise<void> {
  if (wasm != null) {
    return;
  }
  wasm = await wasmImport("gmp");
  // Initialize GMP custom allocator:
  wasm.exports.initCustomAllocator();
}
init();

export class IntegerClass {
  i: number;

  constructor(n: number | string | null, i?: number, base?: number) {
    if (wasm == null) throw Error("await init() first");
    if (n === null && i !== undefined) {
      this.i = i;
    } else if (typeof n == "number") {
      this.i = wasm.exports.createIntegerInt(n);
    } else {
      this.i = wasm.callWithString("createIntegerStr", `${n}`, base ?? 10);
    }
    registry.register(this, this.i); // so we get notified when garbage collected.
  }

  _coerce(m): IntegerClass {
    if (wasm == null) throw Error("await init() first");
    if (!(m instanceof IntegerClass)) {
      return new IntegerClass(m);
    }
    return m;
  }

  _bin_op(m, name: string): IntegerClass {
    m = this._coerce(m);
    const op = wasm?.exports[name];
    if (op === undefined) {
      throw Error(`BUG -- unknown op ${name}`);
    }
    return new IntegerClass(null, op(this.i, m.i));
  }

  __add__(m): IntegerClass {
    return this._bin_op(m, "addIntegers");
  }

  __sub__(m): IntegerClass {
    return this._bin_op(m, "subIntegers");
  }

  __mul__(m): IntegerClass {
    return this._bin_op(m, "mulIntegers");
  }

  __div__(_m): IntegerClass {
    throw Error("NotImplementedError");
  }

  __pow__(e: number): IntegerClass {
    if (wasm == null) throw Error("await init() first");
    return new IntegerClass(null, wasm.exports.powIntegers(this.i, e));
  }

  eql(m): boolean {
    if (wasm == null) throw Error("await init() first");
    if (!(m instanceof IntegerClass)) {
      m = new IntegerClass(m);
    }
    return !!wasm.exports.eqlIntegers(this.i, m.i);
  }

  gcd(m): IntegerClass {
    return this._bin_op(m, "gcdIntegers");
  }

  cmp(m): number {
    m = this._coerce(m);
    return wasm?.exports.cmpIntegers(this.i, m.i);
  }

  print() {
    if (wasm == null) throw Error("await init() first");
    wasm.exports.printInteger(this.i);
  }

  nextPrime() {
    if (wasm == null) throw Error("await init() first");
    return new IntegerClass(null, wasm.exports.nextPrime(this.i));
  }

  isPseudoPrime() {
    if (wasm == null) throw Error("await init() first");
    return wasm.exports.wrappedIsPseudoPrime(this.i);
  }

  toString(base: number = 10): string {
    if (wasm == null) throw Error("await init() first");
    wasm.exports.IntegerToString(this.i, base);
    return wasm.result;
  }

  __repr__(): string {
    return this.toString();
  }
  __str__(): string {
    return this.toString();
  }

  numDigits(base: number = 10): string {
    if (wasm == null) throw Error("await init() first");
    return wasm.exports.sizeInBase(this.i, base);
  }
}

export default function Integer(n: number | string, base: number = 10) {
  return new IntegerClass(n, undefined, base);
}
