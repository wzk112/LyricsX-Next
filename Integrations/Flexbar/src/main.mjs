import { plugin, logger } from '@eniac/flexdesigner';
import { LyricsPlugin } from './lifecycle.mjs';
import { repairHostTransport } from './host.mjs';
const application = new LyricsPlugin(plugin,{logger});
const stopHost = repairHostTransport(plugin,{onLost:()=>application.hostLost(),onReady:()=>application.hostReady()});
let stopped=false;
const stop=()=>{if(stopped)return;stopped=true;application.stop();stopHost();process.exit(0);};
process.on('SIGTERM',stop);process.on('SIGINT',stop);
plugin.start();
