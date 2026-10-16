"""Real embedding, semantic ranking, and persistence, with networking denied."""

from pathlib import Path
import sys
import tempfile


network_attempts = []


def deny_network(event, args):
    if event in ('socket.connect', 'socket.getaddrinfo'):
        network_attempts.append(event)
        raise RuntimeError('Network access is forbidden in the Chroma package check')


sys.addaudithook(deny_network)

import chromadb
from chromadb.utils.embedding_functions import DefaultEmbeddingFunction

with tempfile.TemporaryDirectory() as tmp:
    client = chromadb.PersistentClient(path=tmp)
    collection = client.create_collection('nix-vector-check', embedding_function=DefaultEmbeddingFunction())
    collection.add(ids=['meal', 'database'], documents=[
        'Friends enjoy sandwiches and a picnic in the garden.',
        'SQL database schema migrations require careful transaction handling.',
    ])
    result = collection.query(query_texts=['food eaten outdoors'], n_results=1)
    assert result['ids'] == [['meal']], result
    embeddings = collection.get(include=['embeddings'])['embeddings']
    assert embeddings.shape == (2, 384), embeddings.shape
    client.close()
    reopened = chromadb.PersistentClient(path=tmp)
    result = reopened.get_collection('nix-vector-check').query(
        query_texts=['relational storage upgrade'], n_results=1,
    )
    assert result['ids'] == [['database']], result
    reopened.close()

assert not network_attempts, network_attempts
assert not (Path.home() / '.cache/chroma').exists()
print('Offline MiniLM embeddings, semantic ranking, and Chroma persistence passed')
