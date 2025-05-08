"use client";

import { useAccount } from "wagmi";
import { useNotification } from "@coinbase/onchainkit/minikit";
import { useCallback, useEffect, useState } from "react";
import { ethers } from "ethers";
import TipChainABI from "../../../src/abis/TipChain.json";
import { Button, Card } from "./DemoComponents";

type ChainEntry = {
  from: string;
  to: string;
};

type HomeProps = {
  setActiveTab: (tab: string) => void;
};

export default function Home({ setActiveTab }: HomeProps) {
  const { address } = useAccount();
  const sendNotification = useNotification();

  const [chain, setChain] = useState<ChainEntry[]>([]);
  const [loading, setLoading] = useState(false);
  const [tipInProgress, setTipInProgress] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Replace with your deployed TipChain contract address
  const TIPCHAIN_CONTRACT_ADDRESS = "0x97cEB99cb674f2c3ac2EB7D2a57C7eCEc54B38D8";

  // Load chain data from contract (simplified example)
  const loadChain = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const provider = new ethers.providers.Web3Provider(window.ethereum as any);
      const signer = provider.getSigner();
      const tipChainContract = new ethers.Contract(
        TIPCHAIN_CONTRACT_ADDRESS,
        TipChainABI.abi,
        signer
      );
      // Using getChain with a sample tipId (e.g., 0) to fetch chain addresses
      const tipId = 0;
      const addresses = await tipChainContract.getChain(tipId);
      const entries: ChainEntry[] = [];
      for (let i = 0; i < addresses.length - 1; i++) {
        entries.push({ from: addresses[i], to: addresses[i + 1] });
      }
      setChain(entries);
    } catch (err) {
      setError("Failed to load chain data");
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (address) {
      loadChain();
    }
  }, [address, loadChain]);

  // Handle tip button click
  const handleTip = async () => {
    if (!address) {
      setError("Connect your wallet to tip");
      return;
    }
    setTipInProgress(true);
    setError(null);
    try {
      const provider = new ethers.providers.Web3Provider(window.ethereum as any);
      const signer = provider.getSigner();
      const tipChainContract = new ethers.Contract(
        TIPCHAIN_CONTRACT_ADDRESS,
        TipChainABI.abi,
        signer
      );
      const tx = await tipChainContract.tip();
      await tx.wait();
      await loadChain();
      await sendNotification({
        title: "Tip sent!",
        body: "You successfully tipped and continued the chain.",
      });
    } catch (err) {
      setError("Failed to send tip");
      console.error(err);
    } finally {
      setTipInProgress(false);
    }
  };

  return (
    <div className="space-y-6 animate-fade-in">
      <Card title="TipChain Chat">
        {loading && <p>Loading chain data...</p>}
        {error && <p className="text-red-500">{error}</p>}
        {!loading && !error && (
          <>
            <ul className="mb-4 space-y-2 max-h-48 overflow-auto">
              {chain.length === 0 && <li>No tips in the chain yet.</li>}
              {chain.map((entry, index) => (
                <li key={index}>
                  <strong>{entry.from}</strong> tipped <strong>{entry.to}</strong>
                </li>
              ))}
            </ul>
            <Button
              onClick={handleTip}
              disabled={tipInProgress}
              variant="primary"
              size="md"
            >
              {tipInProgress ? "Tipping..." : "Tip and continue the chain"}
            </Button>
          </>
        )}
      </Card>
    </div>
  );
}