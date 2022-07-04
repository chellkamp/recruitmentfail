
var TestNS = TestNS || {};



function TestClass() {
    const TestEnum = {
        NONE: 0x0,
        LOWER: 0x1,
        UPPER: 0x2
    };
}

console.log(TestClass.TestEnum.UPPER);