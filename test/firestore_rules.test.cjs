const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('../tool/rules/node_modules/@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, Timestamp, serverTimestamp } = require('../tool/rules/node_modules/firebase/firestore');

let env;
const date = Timestamp.fromDate(new Date('2026-10-23T12:00:00Z'));
const debt = (user = 'a', more = {}) => ({user_id:user,nome:'Cliente',telefone:'',valor_principal:100,taxa_juros:10,data_vencimento:date,status_pago:false,client_score:80,created_at:date,...more});
const payment = (user = 'a', debtId = 'd', more = {}) => ({user_id:user,debt_id:debtId,valor:20,data:date,descricao:'Abatimento',...more});
const dbFor = uid => env.authenticatedContext(uid).firestore();
async function seed(data) {
  await env.withSecurityRulesDisabled(async context => {
    for (const [key, value] of Object.entries(data)) await setDoc(doc(context.firestore(), key), value);
  });
}

before(async () => {
  const hostPort = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':');
  env = await initializeTestEnvironment({projectId:'demo-pago',firestore:{host:hostPort[0],port:Number(hostPort[1]),rules:fs.readFileSync(path.join(__dirname,'../firestore.rules'),'utf8')}});
});
beforeEach(async () => env.clearFirestore());
after(async () => { if (env) await env.cleanup(); });

test('legacy debt remains readable and can receive a linked legacy payment', async () => {
  const db = dbFor('a');
  await assertSucceeds(setDoc(doc(db,'Debts/d'),debt()));
  await assertSucceeds(getDoc(doc(db,'Debts/d')));
  await assertSucceeds(setDoc(doc(db,'Payments/p'),payment()));
  await assertFails(getDoc(doc(dbFor('b'),'Debts/d')));
});

test('payment cannot target missing debt or another account debt', async () => {
  await seed({'Debts/foreign':debt('b')});
  const db = dbFor('a');
  await assertFails(setDoc(doc(db,'Payments/p'),payment('a','foreign')));
  await assertFails(setDoc(doc(db,'Payments/p'),payment('a','missing')));
});

test('installment metadata is additive but inconsistent numbering is denied', async () => {
  const db = dbFor('a');
  await assertSucceeds(setDoc(doc(db,'Debts/d'),debt('a',{grupo_id:'g',parcela:2,total_parcelas:3})));
  await assertFails(setDoc(doc(db,'Debts/bad'),debt('a',{grupo_id:'g',parcela:4,total_parcelas:3})));
});

test('first upgraded payment and parent marker commit together', async () => {
  await seed({'Debts/d':debt()});
  const db = dbFor('a');
  const batch = writeBatch(db);
  batch.set(doc(db,'Payments/p'),payment());
  batch.update(doc(db,'Debts/d'),{ledger_revision:1,ledger_payment_id:'p',status_pago:false});
  await assertSucceeds(batch.commit());
  await assertFails(setDoc(doc(db,'Payments/uncoordinated'),payment()));
  const second = writeBatch(db);
  second.set(doc(db,'Payments/p2'),payment());
  second.update(doc(db,'Debts/d'),{ledger_revision:2,ledger_payment_id:'p2',status_pago:false});
  await assertSucceeds(second.commit());
});

test('marked financial terms and revision cannot be changed or reset', async () => {
  await seed({'Debts/d':debt('a',{ledger_revision:1,ledger_payment_id:'p'}),'Payments/p':payment()});
  const db = dbFor('a');
  await assertFails(updateDoc(doc(db,'Debts/d'),{valor_principal:200}));
  await assertFails(updateDoc(doc(db,'Debts/d'),{taxa_juros:20}));
  await assertFails(updateDoc(doc(db,'Debts/d'),{ledger_revision:0,ledger_payment_id:''}));
  await assertFails(updateDoc(doc(db,'Debts/d'),{ledger_revision:2}));
  await assertFails(deleteDoc(doc(db,'Debts/d')));
  await assertSucceeds(updateDoc(doc(db,'Debts/d'),{nome:'Nome corrigido'}));
});

test('reversal preserves original fields and advances parent atomically', async () => {
  await seed({'Debts/d':debt('a',{ledger_revision:1,ledger_payment_id:'p'}),'Payments/p':payment()});
  const db = dbFor('a');
  await assertFails(updateDoc(doc(db,'Payments/p'),{valor:5}));
  await assertFails(updateDoc(doc(db,'Payments/p'),{estornado_em:serverTimestamp(),estorno_motivo:'Correção'}));
  const batch = writeBatch(db);
  batch.update(doc(db,'Payments/p'),{estornado_em:serverTimestamp(),estorno_motivo:'Correção de digitação'});
  batch.update(doc(db,'Debts/d'),{ledger_revision:2,ledger_payment_id:'p',status_pago:false});
  await assertSucceeds(batch.commit());
  await assertFails(deleteDoc(doc(db,'Payments/p')));
});

test('forged ledger marker cannot be supplied on debt creation', async () => {
  const db = dbFor('a');
  await assertFails(setDoc(doc(db,'Debts/d'),debt('a',{ledger_revision:1,ledger_payment_id:'p'})));
});

test('deleted account token cannot recreate or read records', async () => {
  await seed({'DeletedAccounts/a':{deletedAt:date},'Debts/d':debt()});
  const db = dbFor('a');
  await assertFails(getDoc(doc(db,'Debts/d')));
  await assertFails(setDoc(doc(db,'Debts/new'),debt()));
});

test('collection followups are owned, immutable by contact, and not money movement', async () => {
  const db = dbFor('a');
  const followup = {user_id:'a',contact_key:'phone:11999999999',client_name:'Cliente',note:'Combinou sexta',last_contacted_at:null,next_contact_at:date,promised_amount:50,updated_at:serverTimestamp()};
  await assertSucceeds(setDoc(doc(db,'CollectionFollowUps/f'),followup));
  await assertFails(getDoc(doc(dbFor('b'),'CollectionFollowUps/f')));
  await assertFails(updateDoc(doc(db,'CollectionFollowUps/f'),{contact_key:'outro',updated_at:serverTimestamp()}));
  await assertFails(updateDoc(doc(db,'CollectionFollowUps/f'),{promised_amount:-1,updated_at:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(db,'CollectionFollowUps/f'),{note:'Confirmou acordo',updated_at:serverTimestamp()}));
});
