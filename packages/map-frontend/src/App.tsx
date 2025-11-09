import { ApolloProvider } from '@apollo/client';
import { client } from './graphql/client';
import { FlightMap } from './components/Map';
import './App.css';

function App() {
  return (
    <ApolloProvider client={client}>
      <FlightMap />
    </ApolloProvider>
  );
}

export default App;
