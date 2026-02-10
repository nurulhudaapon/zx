import { useState } from "react";

export default function Page(props: { count: number }) {
    const [count, setCount] = useState(props.count);

    return (
        <div>
            <button onClick={handleReset}>Reset</button>
            <h5>{count}</h5>
            <button onClick={handleDecrement}>Decrement</button>
            <button onClick={handleIncrement}>Increment</button>
        </div>
    );

    function handleIncrement() {
        setCount(c => c + 1);
        fetch(`?increment=true`);
    }

    function handleDecrement() {
        setCount(c => c - 1);
        fetch(`?decrement=true`);
    }

    function handleReset() {
        setCount(0);
        fetch(`?reset=true`);
    }
}