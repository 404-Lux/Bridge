import React, { useState } from 'react';
import { Smartphone, Monitor, UploadCloud, Clipboard, CheckCircle2, ShieldCheck, Wifi, RefreshCw, Folder, FileText, Image } from 'lucide-react';

interface TransferItem {
  id: string;
  filename: string;
  size: string;
  status: 'Completed' | 'Transferring' | 'Copied to Clipboard';
  progressPct: number;
}

export default function App() {
  const [isConnected, setIsConnected] = useState<boolean>(true);
  const [deviceName, setDeviceName] = useState<string>("iPhone 15 Pro");
  const [activeTab, setActiveTab] = useState<'workspace' | 'settings'>('workspace');
  const [isDragging, setIsDragging] = useState<boolean>(false);
  const [transfers, setTransfers] = useState<TransferItem[]>([
    { id: '1', filename: 'photo_1725890123.jpg', size: '2.8 MB', status: 'Copied to Clipboard', progressPct: 100 },
    { id: '2', filename: 'document_notes.pdf', size: '4.1 MB', status: 'Completed', progressPct: 100 }
  ]);
  const [clipboardText, setClipboardText] = useState<string>("https://github.com/harramos25/Bridge");

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = () => {
    setIsDragging(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      const droppedFile = e.dataTransfer.files[0];
      const newItem: TransferItem = {
        id: String(Date.now()),
        filename: droppedFile.name,
        size: `${(droppedFile.size / (1024 * 1024)).toFixed(1)} MB`,
        status: 'Completed',
        progressPct: 100
      };
      setTransfers(prev => [newItem, ...prev]);
    }
  };

  const handleSendClipboard = () => {
    const newText = "Copied text from Windows Desktop";
    setClipboardText(newText);
  };

  return (
    <div className="flex h-screen w-screen bg-slate-950 text-slate-100 font-sans p-6 overflow-hidden">
      <div className="w-full max-w-3xl mx-auto space-y-6 flex flex-col justify-between">
        <div className="space-y-6">
          {/* Header Navigation */}
          <header className="flex items-center justify-between border-b border-slate-800 pb-4">
            <div className="flex items-center space-x-3">
              <div className="h-10 w-10 rounded-xl bg-blue-600 flex items-center justify-center shadow-lg shadow-blue-500/20">
                <Smartphone className="h-5 w-5 text-white" />
              </div>
              <div>
                <h1 className="text-lg font-bold">Bridge</h1>
                <p className="text-xs text-slate-400">iPhone ↔ Windows Companion</p>
              </div>
            </div>

            <div className="flex items-center space-x-4">
              <div className="flex items-center space-x-2">
                <span className={`h-2.5 w-2.5 rounded-full ${isConnected ? 'bg-emerald-500 animate-pulse' : 'bg-amber-500'}`} />
                <span className="text-xs font-semibold text-slate-300">
                  {isConnected ? `${deviceName} Connected` : 'Looking for your iPhone...'}
                </span>
              </div>
            </div>
          </header>

          {/* Main Dropzone / Action Area */}
          <div
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
            className={`glass-panel p-8 rounded-2xl border-2 border-dashed transition-all flex flex-col items-center justify-center text-center space-y-3 ${
              isDragging ? 'border-blue-500 bg-blue-500/10 scale-[1.01]' : 'border-slate-800 hover:border-slate-700'
            }`}
          >
            <div className="p-3 rounded-full bg-blue-500/10 text-blue-400">
              <UploadCloud className="h-8 w-8" />
            </div>
            <div>
              <h3 className="text-sm font-semibold text-slate-200">Drop files here to send to iPhone</h3>
              <p className="text-xs text-slate-400 mt-1">Or click to select files from your PC</p>
            </div>
            <div className="flex items-center space-x-3 pt-2">
              <button className="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white font-medium text-xs rounded-xl transition">
                Send Files
              </button>
              <button 
                onClick={handleSendClipboard}
                className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-200 font-medium text-xs rounded-xl transition"
              >
                Send Clipboard
              </button>
            </div>
          </div>

          {/* Transfers & Activity List */}
          <div className="glass-panel p-5 rounded-2xl space-y-3">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-semibold text-slate-200">Transfers & Recent Activity</h3>
              <span className="text-xs text-slate-500">{transfers.length} items</span>
            </div>

            <div className="space-y-2 max-h-48 overflow-y-auto pr-1">
              {transfers.map(item => (
                <div key={item.id} className="flex items-center justify-between p-3 rounded-xl bg-slate-900/80 border border-slate-800/80 text-xs">
                  <div className="flex items-center space-x-3">
                    {item.filename.endsWith('.jpg') ? (
                      <Image className="h-4 w-4 text-indigo-400" />
                    ) : (
                      <FileText className="h-4 w-4 text-blue-400" />
                    )}
                    <div>
                      <p className="font-medium text-slate-200">{item.filename}</p>
                      <p className="text-[11px] text-slate-400">{item.size}</p>
                    </div>
                  </div>
                  <div className="flex items-center space-x-2">
                    <span className="text-[11px] bg-emerald-500/10 text-emerald-400 px-2 py-0.5 rounded border border-emerald-500/20 font-medium">
                      {item.status}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Footer Guarantee Bar */}
        <footer className="flex items-center justify-between text-xs text-slate-500 pt-2 border-t border-slate-900">
          <div className="flex items-center space-x-1 text-slate-400">
            <ShieldCheck className="h-3.5 w-3.5 text-emerald-400" />
            <span>Local-First • ₱0 Budget • Zero Cloud</span>
          </div>
          <span>Bridge v1.0 MVP</span>
        </footer>
      </div>
    </div>
  );
}
