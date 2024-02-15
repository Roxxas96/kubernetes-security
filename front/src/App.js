import { useState } from "react";
import "./App.css";
import logo from "./logo.svg";

function App() {
  const [message, setMessage] = useState("");
  const [answer, setAnswer] = useState("");

  const sendMessage = () => {
    fetch(
      `${process.env.REACT_APP_BACKEND_URL || "http://localhost:3000"}/message`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ message }),
      }
    )
      .then((response) => response.json())
      .then((data) => setAnswer(data.answer))
      .catch((error) => console.log(error));
  };

  return (
    <div className="App">
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
        <input
          type="text"
          value={message}
          onChange={(event) => {
            setMessage(event.target.value);
          }}
        />
        <button onClick={sendMessage}>Send message</button>
        <p>{answer}</p>
      </header>
    </div>
  );
}

export default App;
