// Testes das Security Rules do Firestore do Nexo (firestore.rules).
// Rodam só no emulador, com o projeto fictício demo-nexo: nada chega ao
// projeto real. Rodam uma vez antes de cada deploy das regras.
// Como rodar: docs/backend/firestore-rules.md, seção 2.

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  setLogLevel,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const ALICE = 'alice';
const BOB = 'bob';
const HOUR = 60 * 60 * 1000;
const TERMS = 'terms-2026-11-01';
const PRIVACY = 'privacy-2026-11-01';
const USER = `users/${ALICE}`;
const PLAN = `users/${ALICE}/plans/p1`;

let env;

before(async () => {
  setLogLevel('error');
  env = await initializeTestEnvironment({
    projectId: 'demo-nexo',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  // Conteúdo carregado pelo console antes do lançamento.
  await seed('legalDocuments/current', { termsVersion: TERMS, privacyVersion: PRIVACY });
  await seed('achievementsCatalog/semana-em-dia', { title: 'Semana em dia' });
});

// Firestore como o app veria: logado como `uid` (com e-mail verificado,
// a menos que `verified` seja false) ou sem login.
function db(uid, { verified = true } = {}) {
  return uid
    ? env.authenticatedContext(uid, { email_verified: verified }).firestore()
    : env.unauthenticatedContext().firestore();
}

// Grava dados de apoio sem passar pelas regras.
async function seed(path, data) {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));
}

function ago(ms) {
  return Timestamp.fromMillis(Date.now() - ms);
}

function later(ms) {
  return Timestamp.fromMillis(Date.now() + ms);
}

// Data AAAA-MM-DD (UTC) de `years` anos atrás, deslocada `days` dias.
function birthDate(years, days = 0) {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + days);
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getUTCFullYear() - years}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

// Data AAAA-MM-DD (UTC) de hoje deslocada `days` dias.
function isoDate(days = 0) {
  return birthDate(0, days);
}

// ---------- Documentos válidos, como o app gravaria ----------

function newUser(extra = {}) {
  return {
    displayName: 'Ana',
    birthDate: '2000-05-10',
    timeZone: 'America/Sao_Paulo',
    tutorialSeen: false,
    consents: {
      termsVersion: TERMS,
      privacyVersion: PRIVACY,
      acceptedAt: serverTimestamp(),
    },
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...extra,
  };
}

function storedUser(extra = {}) {
  return {
    displayName: 'Ana',
    birthDate: '2000-05-10',
    timeZone: 'America/Sao_Paulo',
    tutorialSeen: true,
    consents: {
      termsVersion: TERMS,
      privacyVersion: PRIVACY,
      acceptedAt: ago(24 * HOUR),
    },
    points: 42,
    createdAt: ago(24 * HOUR),
    updatedAt: ago(24 * HOUR),
    ...extra,
  };
}

function newPlan(extra = {}) {
  return {
    name: 'Concurso Banco do Brasil',
    startDate: isoDate(0),
    endDate: isoDate(150),
    frequency: { type: 'daily' },
    dailyGoalMinutes: 120,
    status: 'active',
    goalId: null,
    reminder: { enabled: true, time: '19:30' },
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...extra,
  };
}

function storedPlan(extra = {}) {
  return { ...newPlan(), createdAt: ago(HOUR), updatedAt: ago(HOUR), ...extra };
}

function newSession(extra = {}) {
  return {
    startAt: ago(2 * HOUR),
    endAt: ago(HOUR),
    durationSeconds: 3000,
    source: 'manual',
    topicId: 'interpretacao-de-texto',
    note: 'Interpretação de texto — lista 4',
    day: isoDate(0),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...extra,
  };
}

function storedSession(extra = {}) {
  return { ...newSession(), createdAt: ago(HOUR), updatedAt: ago(HOUR), ...extra };
}

function newDay(extra = {}) {
  return {
    doneMinutes: 50,
    finalizedAt: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...extra,
  };
}

function storedDay(extra = {}) {
  return { ...newDay(), createdAt: ago(HOUR), updatedAt: ago(HOUR), ...extra };
}

function newTask(extra = {}) {
  return {
    title: 'Entregar resumo',
    subjectId: null,
    dueAt: later(24 * HOUR),
    priority: 'high',
    completed: false,
    completedAt: null,
    reminderMinutesBefore: 1440,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...extra,
  };
}

// ---------- users/{uid} ----------

describe('users/{uid}: cadastro', () => {
  test('o dono cria o próprio documento com o aceite e a data de nascimento', async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), USER), newUser()));
  });

  test('ninguém cria o documento de outro usuário; sem login também não', async () => {
    await assertFails(setDoc(doc(db(BOB), USER), newUser()));
    await assertFails(setDoc(doc(db(), USER), newUser()));
  });

  test('e-mail ainda não verificado: só cria o próprio documento', async () => {
    const unverified = db(ALICE, { verified: false });
    await assertSucceeds(setDoc(doc(unverified, USER), newUser()));
    await assertFails(getDoc(doc(unverified, USER)));
    await assertFails(updateDoc(doc(unverified, USER), { tutorialSeen: true, updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(unverified, PLAN), newPlan()));
  });

  test('sem aceite ou com aceite incompleto não cria', async () => {
    const semAceite = newUser();
    delete semAceite.consents;
    await assertFails(setDoc(doc(db(ALICE), USER), semAceite));
    const semPolitica = newUser();
    delete semPolitica.consents.privacyVersion;
    await assertFails(setDoc(doc(db(ALICE), USER), semPolitica));
  });

  test('aceite com hora do aparelho ou versão que não é a vigente é negado', async () => {
    const horaAparelho = newUser();
    horaAparelho.consents.acceptedAt = ago(HOUR);
    await assertFails(setDoc(doc(db(ALICE), USER), horaAparelho));
    const versaoAntiga = newUser();
    versaoAntiga.consents.termsVersion = 'terms-2025-01-01';
    await assertFails(setDoc(doc(db(ALICE), USER), versaoAntiga));
  });

  test('sem o documento de versões vigentes ninguém cria conta', async () => {
    await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'legalDocuments/current')));
    await assertFails(setDoc(doc(db(ALICE), USER), newUser()));
  });

  test('idade mínima de 16 anos pela data de nascimento', async () => {
    const ref = doc(db(ALICE), USER);
    await assertFails(setDoc(ref, newUser({ birthDate: birthDate(16, 1) }))); // faz 16 amanhã
    await assertFails(setDoc(ref, newUser({ birthDate: birthDate(10) })));
    await assertFails(setDoc(ref, newUser({ birthDate: '10/05/2000' })));
    await assertFails(setDoc(ref, newUser({ birthDate: '1899-12-31' })));
    const semData = newUser();
    delete semData.birthDate;
    await assertFails(setDoc(ref, semData));
    await assertSucceeds(setDoc(ref, newUser({ birthDate: birthDate(16) }))); // faz 16 hoje
  });

  test('começa com 0 pontos', async () => {
    await assertFails(setDoc(doc(db(ALICE), USER), newUser({ points: 100 })));
    await assertSucceeds(setDoc(doc(db(ALICE), USER), newUser({ points: 0 })));
  });

  test('campos inválidos ou fora do contrato são negados', async () => {
    const ref = doc(db(ALICE), USER);
    await assertFails(setDoc(ref, newUser({ timeZone: 'São Paulo' })));
    await assertFails(setDoc(ref, newUser({ displayName: '' })));
    await assertFails(setDoc(ref, newUser({ displayName: 'a'.repeat(81) })));
    await assertFails(setDoc(ref, newUser({ locale: 'pt-BR' })));
    await assertFails(setDoc(ref, newUser({ photoUrl: 'x' })));
    await assertFails(setDoc(ref, newUser({ notifications: { enabled: true } })));
    await assertFails(setDoc(ref, newUser({ createdAt: ago(HOUR) })));
    await assertFails(setDoc(ref, newUser({ overloadThreshold: 0 })));
    await assertFails(setDoc(ref, newUser({ overloadThreshold: 21 })));
    await assertSucceeds(setDoc(ref, newUser({ overloadThreshold: 5 })));
  });
});

describe('users/{uid}: uso', () => {
  test('só o dono lê', async () => {
    await seed(USER, storedUser());
    await assertSucceeds(getDoc(doc(db(ALICE), USER)));
    await assertFails(getDoc(doc(db(BOB), USER)));
    await assertFails(getDoc(doc(db(), USER)));
  });

  test('o dono altera o nome, com updatedAt do servidor', async () => {
    await seed(USER, storedUser());
    const ref = doc(db(ALICE), USER);
    await assertFails(updateDoc(ref, { displayName: 'Ana Paula' }));
    await assertSucceeds(updateDoc(ref, { displayName: 'Ana Paula', updatedAt: serverTimestamp() }));
  });

  test('o app mantém os pontos dentro dos limites', async () => {
    await seed(USER, storedUser());
    const ref = doc(db(ALICE), USER);
    await assertSucceeds(updateDoc(ref, { points: 49, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { points: -1, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { points: 1.5, updatedAt: serverTimestamp() }));
  });

  test('o app não altera a data de nascimento nem o createdAt', async () => {
    await seed(USER, storedUser());
    const ref = doc(db(ALICE), USER);
    await assertFails(updateDoc(ref, { birthDate: '1999-01-01', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { createdAt: serverTimestamp(), updatedAt: serverTimestamp() }));
  });

  test('nova versão vigente: novo aceite com a hora do servidor', async () => {
    await seed(USER, storedUser());
    await seed('legalDocuments/current', { termsVersion: 'terms-2027-01-01', privacyVersion: 'privacy-2027-01-01' });
    const ref = doc(db(ALICE), USER);
    const novo = { termsVersion: 'terms-2027-01-01', privacyVersion: 'privacy-2027-01-01' };
    await assertFails(updateDoc(ref, { consents: { ...novo, acceptedAt: ago(HOUR) }, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, {
      consents: { termsVersion: TERMS, privacyVersion: PRIVACY, acceptedAt: serverTimestamp() },
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(ref, { consents: { ...novo, acceptedAt: serverTimestamp() }, updatedAt: serverTimestamp() }));
  });

  test('o aceite não pode ser removido', async () => {
    await seed(USER, storedUser());
    await assertFails(updateDoc(doc(db(ALICE), USER), { consents: deleteField(), updatedAt: serverTimestamp() }));
  });
});

describe('users/{uid}: excluir conta pelo app', () => {
  test('sem a marcação de exclusão, o documento não é apagado', async () => {
    await seed(USER, storedUser());
    await assertFails(deleteDoc(doc(db(ALICE), USER)));
  });

  test('marcação com a hora do servidor, uma vez só', async () => {
    await seed(USER, storedUser());
    const ref = doc(db(ALICE), USER);
    await assertFails(updateDoc(ref, { deletionRequestedAt: ago(HOUR), updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref, { deletionRequestedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { deletionRequestedAt: null, updatedAt: serverTimestamp() }));
  });

  test('com a marcação: apaga dados imutáveis e, por último, o usuário', async () => {
    await seed(USER, storedUser({ deletionRequestedAt: ago(1000) }));
    await seed(PLAN, storedPlan());
    await seed(`${PLAN}/scheduleVersions/v0`, { effectiveFrom: isoDate(0), frequency: { type: 'daily' }, dailyGoalMinutes: 120, createdAt: ago(HOUR) });
    await seed(`${PLAN}/days/${isoDate(-30)}`, storedDay());
    await seed(`${PLAN}/sessions/antiga`, storedSession({ day: isoDate(-30) }));
    await seed(`${USER}/achievements/semana-em-dia`, { earnedAt: ago(HOUR) });
    const d = db(ALICE);
    await assertSucceeds(deleteDoc(doc(d, `${PLAN}/scheduleVersions/v0`)));
    await assertSucceeds(deleteDoc(doc(d, `${PLAN}/days/${isoDate(-30)}`)));
    await assertSucceeds(deleteDoc(doc(d, `${PLAN}/sessions/antiga`)));
    await assertSucceeds(deleteDoc(doc(d, `${USER}/achievements/semana-em-dia`)));
    await assertSucceeds(deleteDoc(doc(d, PLAN)));
    await assertSucceeds(deleteDoc(doc(d, USER)));
  });

  test('outro usuário não apaga', async () => {
    await seed(USER, storedUser({ deletionRequestedAt: ago(1000) }));
    await assertFails(deleteDoc(doc(db(BOB), USER)));
  });
});

// ---------- goals ----------

describe('users/{uid}/goals', () => {
  const goal = (extra = {}) => ({
    name: 'Passar no concurso',
    description: null,
    deadline: '2027-06-30',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...extra,
  });

  test('o dono cria, altera e apaga', async () => {
    const ref = doc(db(ALICE), `${USER}/goals/g1`);
    await assertSucceeds(setDoc(ref, goal()));
    await assertSucceeds(updateDoc(ref, { name: 'Novo nome', updatedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(ref));
  });

  test('nome vazio e prazo inválido são negados', async () => {
    const ref = doc(db(ALICE), `${USER}/goals/g1`);
    await assertFails(setDoc(ref, goal({ name: '' })));
    await assertFails(setDoc(ref, goal({ deadline: '30/06/2027' })));
  });

  test('outro usuário não lê', async () => {
    await seed(`${USER}/goals/g1`, { ...goal(), createdAt: ago(HOUR), updatedAt: ago(HOUR) });
    await assertFails(getDoc(doc(db(BOB), `${USER}/goals/g1`)));
  });
});

// ---------- plans ----------

describe('users/{uid}/plans', () => {
  test('o dono cria planos com as três frequências', async () => {
    const d = db(ALICE);
    await assertSucceeds(setDoc(doc(d, `${USER}/plans/a`), newPlan()));
    await assertSucceeds(setDoc(doc(d, `${USER}/plans/b`), newPlan({ frequency: { type: 'weekdays', weekdays: [1, 3, 5] } })));
    await assertSucceeds(setDoc(doc(d, `${USER}/plans/c`), newPlan({ frequency: { type: 'timesPerWeek', timesPerWeek: 3 } })));
  });

  test('frequência inválida é negada', async () => {
    const ref = doc(db(ALICE), PLAN);
    await assertFails(setDoc(ref, newPlan({ frequency: { type: 'weekdays', weekdays: [] } })));
    await assertFails(setDoc(ref, newPlan({ frequency: { type: 'weekdays', weekdays: [8] } })));
    await assertFails(setDoc(ref, newPlan({ frequency: { type: 'timesPerWeek', timesPerWeek: 0 } })));
    await assertFails(setDoc(ref, newPlan({ frequency: { type: 'daily', weekdays: [1] } })));
    await assertFails(setDoc(ref, newPlan({ frequency: { type: 'monthly' } })));
  });

  test('início até 7 dias para trás e período de até 2 anos', async () => {
    const d = db(ALICE);
    await assertSucceeds(setDoc(doc(d, `${USER}/plans/a`), newPlan({ startDate: isoDate(-7) })));
    await assertFails(setDoc(doc(d, `${USER}/plans/b`), newPlan({ startDate: isoDate(-10) })));
    await assertSucceeds(setDoc(doc(d, `${USER}/plans/c`), newPlan({ endDate: isoDate(731) })));
    await assertFails(setDoc(doc(d, `${USER}/plans/e`), newPlan({ endDate: isoDate(732) })));
  });

  test('datas, meta, status e lembrete inválidos são negados', async () => {
    const ref = doc(db(ALICE), PLAN);
    await assertFails(setDoc(ref, newPlan({ startDate: isoDate(10), endDate: isoDate(5) })));
    await assertFails(setDoc(ref, newPlan({ startDate: '2026-13-01' })));
    await assertFails(setDoc(ref, newPlan({ dailyGoalMinutes: 0 })));
    await assertFails(setDoc(ref, newPlan({ dailyGoalMinutes: 1441 })));
    await assertFails(setDoc(ref, newPlan({ dailyGoalMinutes: 1.5 })));
    await assertFails(setDoc(ref, newPlan({ status: 'deleted' })));
    await assertFails(setDoc(ref, newPlan({ status: 'deleting' })));
    await assertFails(setDoc(ref, newPlan({ reminder: { enabled: true, time: '7h' } })));
  });

  test('campos fora do contrato (isPrimary, totais) são negados', async () => {
    await assertFails(setDoc(doc(db(ALICE), PLAN), newPlan({ isPrimary: true })));
    await assertFails(setDoc(doc(db(ALICE), PLAN), newPlan({ doneMinutes: 999 })));
  });

  test('pausar e encerrar antes (endedOn dentro do período)', async () => {
    await seed(PLAN, storedPlan());
    const ref = doc(db(ALICE), PLAN);
    await assertSucceeds(updateDoc(ref, {
      status: 'paused', pauses: [{ start: isoDate(0), end: null }], updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(ref, { status: 'endedEarly', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { status: 'endedEarly', endedOn: isoDate(200), updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref, { status: 'endedEarly', endedOn: isoDate(1), updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref, { status: 'archived', updatedAt: serverTimestamp() }));
  });

  test('o dono lista e apaga os próprios planos; outro usuário não', async () => {
    await seed(USER, storedUser());
    await seed(PLAN, storedPlan());
    await assertSucceeds(getDocs(collection(db(ALICE), `${USER}/plans`)));
    await assertFails(getDocs(collection(db(BOB), `${USER}/plans`)));
    await assertFails(deleteDoc(doc(db(BOB), PLAN)));
    await assertSucceeds(deleteDoc(doc(db(ALICE), PLAN)));
  });

  test('excluir plano: marca "excluindo" e libera apagar dias e versões', async () => {
    await seed(USER, storedUser());
    await seed(PLAN, storedPlan());
    await seed(`${PLAN}/scheduleVersions/v0`, { effectiveFrom: isoDate(0), frequency: { type: 'daily' }, dailyGoalMinutes: 120, createdAt: ago(HOUR) });
    await seed(`${PLAN}/days/${isoDate(0)}`, storedDay());
    const d = db(ALICE);
    await assertFails(deleteDoc(doc(d, `${PLAN}/scheduleVersions/v0`)));
    await assertFails(deleteDoc(doc(d, `${PLAN}/days/${isoDate(0)}`)));
    await assertSucceeds(updateDoc(doc(d, PLAN), { status: 'deleting', updatedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(doc(d, `${PLAN}/scheduleVersions/v0`)));
    await assertSucceeds(deleteDoc(doc(d, `${PLAN}/days/${isoDate(0)}`)));
    await assertSucceeds(deleteDoc(doc(d, PLAN)));
  });
});

// ---------- plano principal (users.primaryPlanId) ----------

describe('plano principal', () => {
  test('aponta só para um plano que existe', async () => {
    await seed(USER, storedUser());
    await seed(PLAN, storedPlan());
    const ref = doc(db(ALICE), USER);
    await assertFails(updateDoc(ref, { primaryPlanId: 'nao-existe', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref, { primaryPlanId: 'p1', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref, { primaryPlanId: null, updatedAt: serverTimestamp() }));
  });

  test('criar plano + versão inicial + principal numa operação só', async () => {
    await seed(USER, storedUser());
    const d = db(ALICE);
    const plan = newPlan();
    const batch = writeBatch(d);
    batch.set(doc(d, PLAN), plan);
    batch.set(doc(d, `${PLAN}/scheduleVersions/v0`), {
      effectiveFrom: plan.startDate,
      frequency: plan.frequency,
      dailyGoalMinutes: plan.dailyGoalMinutes,
      createdAt: serverTimestamp(),
    });
    batch.update(doc(d, USER), { primaryPlanId: 'p1', updatedAt: serverTimestamp() });
    await assertSucceeds(batch.commit());
  });

  test('apagar o plano principal exige limpar o principal junto', async () => {
    await seed(USER, storedUser({ primaryPlanId: 'p1' }));
    await seed(PLAN, storedPlan());
    const d = db(ALICE);
    await assertFails(deleteDoc(doc(d, PLAN)));
    const batch = writeBatch(d);
    batch.delete(doc(d, PLAN));
    batch.update(doc(d, USER), { primaryPlanId: null, updatedAt: serverTimestamp() });
    await assertSucceeds(batch.commit());
  });
});

// ---------- scheduleVersions ----------

describe('users/{uid}/plans/{planId}/scheduleVersions', () => {
  const version = (extra = {}) => ({
    effectiveFrom: isoDate(10),
    frequency: { type: 'weekdays', weekdays: [1, 2, 3, 4, 5] },
    dailyGoalMinutes: 90,
    createdAt: serverTimestamp(),
    ...extra,
  });

  test('o dono registra uma versão num plano existente', async () => {
    await seed(PLAN, storedPlan());
    await assertSucceeds(setDoc(doc(db(ALICE), `${PLAN}/scheduleVersions/v1`), version()));
  });

  test('plano inexistente ou vigência fora do período é negado', async () => {
    await assertFails(setDoc(doc(db(ALICE), `${PLAN}/scheduleVersions/v1`), version()));
    await seed(PLAN, storedPlan());
    await assertFails(setDoc(doc(db(ALICE), `${PLAN}/scheduleVersions/v1`), version({ effectiveFrom: isoDate(-1) })));
    await assertFails(setDoc(doc(db(ALICE), `${PLAN}/scheduleVersions/v2`), version({ effectiveFrom: isoDate(151) })));
  });

  test('o histórico é imutável para o app', async () => {
    await seed(PLAN, storedPlan());
    await seed(`${PLAN}/scheduleVersions/v1`, { ...version(), createdAt: ago(HOUR) });
    const ref = doc(db(ALICE), `${PLAN}/scheduleVersions/v1`);
    await assertFails(updateDoc(ref, { dailyGoalMinutes: 30 }));
    await assertFails(deleteDoc(ref));
  });
});

// ---------- topics ----------

describe('users/{uid}/plans/{planId}/topics', () => {
  const topic = (extra = {}) => ({
    name: 'Porcentagem',
    subjectId: 'matematica',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...extra,
  });
  const ref = (id = 't1', uid = ALICE) => doc(db(uid), `${PLAN}/topics/${id}`);

  test('vários tópicos da mesma matéria e tópico novo, só do plano', async () => {
    await seed(PLAN, storedPlan());
    await assertSucceeds(setDoc(ref('t1'), topic()));
    await assertSucceeds(setDoc(ref('t2'), topic({ name: 'Juros simples' })));
    await assertSucceeds(setDoc(ref('t3'), topic({ name: 'Raciocínio lógico', subjectId: null })));
  });

  test('criar o plano com seus tópicos numa operação só', async () => {
    const d = db(ALICE);
    const batch = writeBatch(d);
    batch.set(doc(d, PLAN), newPlan());
    batch.set(doc(d, `${PLAN}/topics/t1`), topic());
    await assertSucceeds(batch.commit());
  });

  test('o dono renomeia e apaga; outro usuário não lê', async () => {
    await seed(PLAN, storedPlan());
    await assertSucceeds(setDoc(ref(), topic()));
    await assertSucceeds(updateDoc(ref(), { name: 'Porcentagem e juros', updatedAt: serverTimestamp() }));
    await assertFails(getDoc(ref('t1', BOB)));
    await assertSucceeds(deleteDoc(ref()));
  });

  test('plano inexistente, nome inválido e campos extras são negados', async () => {
    await assertFails(setDoc(ref(), topic()));
    await seed(PLAN, storedPlan());
    await assertFails(setDoc(ref(), topic({ name: '' })));
    await assertFails(setDoc(ref(), topic({ name: 'a'.repeat(81) })));
    await assertFails(setDoc(ref(), topic({ hours: 10 })));
  });
});

// ---------- sessions ----------

describe('users/{uid}/plans/{planId}/sessions', () => {
  const ref = (uid = ALICE, id = 's1') => doc(db(uid), `${PLAN}/sessions/${id}`);

  beforeEach(async () => {
    await seed(PLAN, storedPlan());
  });

  test('sessão encerrada (foco ou manual) é gravada', async () => {
    await assertSucceeds(setDoc(ref(), newSession()));
    await assertSucceeds(setDoc(ref(ALICE, 's2'), newSession({ source: 'focus', topicId: null, note: null })));
  });

  test('não existe sessão em andamento no Firestore', async () => {
    await assertFails(setDoc(ref(), newSession({ source: 'focus', endAt: null, durationSeconds: null })));
  });

  test('horários incoerentes são negados', async () => {
    await assertFails(setDoc(ref(), newSession({ startAt: ago(HOUR), endAt: ago(2 * HOUR) })));
    await assertFails(setDoc(ref(), newSession({ startAt: ago(26 * HOUR), endAt: ago(HOUR) })));
    await assertFails(setDoc(ref(), newSession({ durationSeconds: 3601 })));
    await assertFails(setDoc(ref(), newSession({ durationSeconds: 0 })));
    await assertFails(setDoc(ref(), newSession({ startAt: later(HOUR), endAt: later(2 * HOUR) })));
  });

  test('janela de 7 dias para registrar', async () => {
    await assertSucceeds(setDoc(ref(ALICE, 'a'), newSession({ day: isoDate(-7) })));
    await assertFails(setDoc(ref(ALICE, 'b'), newSession({ day: isoDate(-10) })));
    await assertFails(setDoc(ref(ALICE, 'c'), newSession({ day: isoDate(3) })));
  });

  test('campos fora do contrato e textos inválidos são negados', async () => {
    await assertFails(setDoc(ref(), newSession({ day: '22/10/2026' })));
    await assertFails(setDoc(ref(), newSession({ source: 'import' })));
    await assertFails(setDoc(ref(), newSession({ note: 'a'.repeat(501) })));
    await assertFails(setDoc(ref(), newSession({ topic: 'Português' })));
    await assertFails(setDoc(ref(), newSession({ subjectId: 'portugues' })));
    await assertFails(setDoc(ref(), newSession({ pauses: [] })));
  });

  test('plano inexistente é negado', async () => {
    await assertFails(setDoc(doc(db(ALICE), `${USER}/plans/nao-existe/sessions/s1`), newSession()));
  });

  test('o dono edita e apaga dentro da janela; outro usuário não', async () => {
    await assertSucceeds(setDoc(ref(), newSession()));
    await assertFails(getDoc(ref(BOB)));
    await assertFails(updateDoc(ref(BOB), { note: 'x', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref(), { topicId: 'porcentagem', updatedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(ref()));
  });

  test('sessão de mais de 7 dias não é editada nem apagada', async () => {
    await seed(`${PLAN}/sessions/antiga`, storedSession({ day: isoDate(-30) }));
    await assertFails(updateDoc(ref(ALICE, 'antiga'), { note: 'x', updatedAt: serverTimestamp() }));
    await assertFails(deleteDoc(ref(ALICE, 'antiga')));
  });
});

// ---------- days ----------

describe('users/{uid}/plans/{planId}/days', () => {
  const dayRef = (date, uid = ALICE) => doc(db(uid), `${PLAN}/days/${date}`);

  beforeEach(async () => {
    await seed(PLAN, storedPlan());
  });

  test('o app grava o realizado do dia junto com a sessão', async () => {
    const d = db(ALICE);
    const batch = writeBatch(d);
    batch.set(doc(d, `${PLAN}/sessions/s1`), newSession());
    batch.set(doc(d, `${PLAN}/days/${isoDate(0)}`), newDay());
    await assertSucceeds(batch.commit());
  });

  test('finalizar com a hora do servidor e desfazer', async () => {
    await seed(`${PLAN}/days/${isoDate(0)}`, storedDay());
    await assertFails(updateDoc(dayRef(isoDate(0)), { finalizedAt: ago(HOUR), updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(dayRef(isoDate(0)), { finalizedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(dayRef(isoDate(0)), { finalizedAt: null, updatedAt: serverTimestamp() }));
  });

  test('finalizar até 7 dias para trás (RF14)', async () => {
    await assertSucceeds(setDoc(dayRef(isoDate(-7)), newDay({ finalizedAt: serverTimestamp() })));
    await assertFails(setDoc(dayRef(isoDate(-10)), newDay({ finalizedAt: serverTimestamp() })));
    await seed(`${PLAN}/days/${isoDate(-30)}`, storedDay());
    await assertFails(updateDoc(dayRef(isoDate(-30)), { finalizedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
  });

  test('valores e campos fora do contrato são negados', async () => {
    await assertFails(setDoc(dayRef(isoDate(0)), newDay({ doneMinutes: 1441 })));
    await assertFails(setDoc(dayRef(isoDate(0)), newDay({ doneMinutes: -1 })));
    await assertFails(setDoc(dayRef(isoDate(0)), newDay({ status: 'met' })));
    await assertFails(setDoc(dayRef(isoDate(0)), newDay({ points: 5 })));
    await assertFails(setDoc(dayRef('hoje'), newDay()));
  });

  test('plano inexistente é negado; outro usuário não lê', async () => {
    await assertFails(setDoc(doc(db(ALICE), `${USER}/plans/nao-existe/days/${isoDate(0)}`), newDay()));
    await seed(`${PLAN}/days/${isoDate(0)}`, storedDay());
    await assertSucceeds(getDoc(dayRef(isoDate(0))));
    await assertFails(getDoc(dayRef(isoDate(0), BOB)));
  });

  test('o dia não é apagado no uso normal', async () => {
    await seed(`${PLAN}/days/${isoDate(0)}`, storedDay());
    await assertFails(deleteDoc(dayRef(isoDate(0))));
  });
});

// ---------- tasks ----------

describe('users/{uid}/tasks', () => {
  const ref = (uid = ALICE, id = 't1') => doc(db(uid), `${USER}/tasks/${id}`);

  test('o dono cria tarefa com aviso e tarefa sem prazo', async () => {
    await assertSucceeds(setDoc(ref(), newTask()));
    await assertSucceeds(setDoc(ref(ALICE, 't2'), newTask({ dueAt: null, reminderMinutesBefore: null, priority: 'none' })));
  });

  test('aviso: 1 hora, 1 dia, 1 semana ou personalizado até 30 dias, só com prazo', async () => {
    for (const [id, minutes] of [['a', 60], ['b', 1440], ['c', 10080], ['d', 45], ['e', 43200]]) {
      await assertSucceeds(setDoc(ref(ALICE, id), newTask({ reminderMinutesBefore: minutes })));
    }
    await assertFails(setDoc(ref(ALICE, 'f'), newTask({ reminderMinutesBefore: 43201 })));
    await assertFails(setDoc(ref(ALICE, 'g'), newTask({ reminderMinutesBefore: 0 })));
    await assertFails(setDoc(ref(ALICE, 'h'), newTask({ dueAt: null, reminderMinutesBefore: 60 })));
  });

  test('conclusão coerente com completedAt do servidor', async () => {
    await assertSucceeds(setDoc(ref(), newTask({ completed: true, completedAt: serverTimestamp() })));
    await assertFails(setDoc(ref(ALICE, 't2'), newTask({ completed: true, completedAt: null })));
    await assertFails(setDoc(ref(ALICE, 't3'), newTask({ completed: false, completedAt: serverTimestamp() })));
    await assertFails(setDoc(ref(ALICE, 't4'), newTask({ completed: true, completedAt: ago(HOUR) })));
  });

  test('concluir, editar concluída e reabrir', async () => {
    await assertSucceeds(setDoc(ref(), newTask()));
    await assertSucceeds(updateDoc(ref(), { completed: true, completedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref(), { title: 'Resumo final', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref(), { completed: false, completedAt: null, updatedAt: serverTimestamp() }));
  });

  test('situação da entrega coerente com a conclusão', async () => {
    await assertSucceeds(setDoc(ref(ALICE, 'a'), newTask({ deliveryStatus: 'notStarted' })));
    await assertSucceeds(setDoc(ref(ALICE, 'b'), newTask({ deliveryStatus: 'inProgress' })));
    await assertSucceeds(setDoc(ref(ALICE, 'c'), newTask({ completed: true, completedAt: serverTimestamp(), deliveryStatus: 'delivered' })));
    await assertSucceeds(setDoc(ref(ALICE, 'd'), newTask({ completed: true, completedAt: serverTimestamp(), deliveryStatus: 'awaitingGrade' })));
    await assertSucceeds(setDoc(ref(ALICE, 'e'), newTask({ deliveryStatus: null })));
    // pendente não pode estar entregue; concluída não pode estar "não iniciada"
    await assertFails(setDoc(ref(ALICE, 'f'), newTask({ deliveryStatus: 'delivered' })));
    await assertFails(setDoc(ref(ALICE, 'g'), newTask({ completed: true, completedAt: serverTimestamp(), deliveryStatus: 'notStarted' })));
    await assertFails(setDoc(ref(ALICE, 'h'), newTask({ deliveryStatus: 'Entregue' })));
  });

  test('concluir junto com a situação "Entregue"', async () => {
    await assertSucceeds(setDoc(ref(), newTask({ deliveryStatus: 'inProgress' })));
    await assertFails(updateDoc(ref(), { completed: true, completedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref(), {
      completed: true, completedAt: serverTimestamp(), deliveryStatus: 'delivered', updatedAt: serverTimestamp(),
    }));
  });

  test('campos inválidos ou fora do MVP são negados', async () => {
    await assertFails(setDoc(ref(), newTask({ priority: 'urgent' })));
    await assertFails(setDoc(ref(), newTask({ title: '' })));
    await assertFails(setDoc(ref(), newTask({ notes: 'texto' })));
  });

  test('outro usuário não lê', async () => {
    await assertSucceeds(setDoc(ref(), newTask()));
    await assertFails(getDoc(ref(BOB)));
    await assertFails(getDocs(collection(db(BOB), `${USER}/tasks`)));
  });
});

// ---------- subjects ----------

describe('users/{uid}/subjects', () => {
  const subject = (extra = {}) => ({
    name: 'Cálculo I', icon: 'calculator', color: 'azul',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...extra,
  });

  test('ícone e cor são obrigatórios', async () => {
    const ref = doc(db(ALICE), `${USER}/subjects/sub1`);
    const semCor = subject();
    delete semCor.color;
    await assertFails(setDoc(ref, semCor));
    await assertFails(setDoc(ref, subject({ color: '' })));
    await assertSucceeds(setDoc(ref, subject()));
    await assertSucceeds(updateDoc(ref, { color: 'verde', updatedAt: serverTimestamp() }));
  });

  test('o dono cria, renomeia e apaga', async () => {
    const ref = doc(db(ALICE), `${USER}/subjects/sub1`);
    await assertSucceeds(setDoc(ref, subject()));
    await assertSucceeds(updateDoc(ref, { name: 'Cálculo II', updatedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(ref));
  });

  test('contagens não são guardadas (o app calcula)', async () => {
    await assertFails(setDoc(doc(db(ALICE), `${USER}/subjects/sub1`), subject({ deliveriesDone: 3 })));
  });
});

// ---------- achievements ----------

describe('users/{uid}/achievements', () => {
  const ref = (id = 'semana-em-dia', uid = ALICE) => doc(db(uid), `${USER}/achievements/${id}`);

  test('o app grava conquista do catálogo com a hora do servidor', async () => {
    await assertSucceeds(setDoc(ref(), { earnedAt: serverTimestamp() }));
    await assertSucceeds(getDoc(ref()));
    await assertFails(getDoc(ref('semana-em-dia', BOB)));
  });

  test('fora do catálogo, com hora do aparelho ou com campos extras é negado', async () => {
    await assertFails(setDoc(ref('inventada'), { earnedAt: serverTimestamp() }));
    await assertFails(setDoc(ref(), { earnedAt: ago(HOUR) }));
    await assertFails(setDoc(ref(), { earnedAt: serverTimestamp(), points: 100 }));
  });

  test('conquista não muda nem sai no uso normal', async () => {
    await seed(`${USER}/achievements/semana-em-dia`, { earnedAt: ago(HOUR) });
    await assertFails(updateDoc(ref(), { earnedAt: serverTimestamp() }));
    await assertFails(deleteDoc(ref()));
  });
});

// ---------- conteúdo do app ----------

describe('achievementsCatalog e legalDocuments (somente leitura)', () => {
  test('catálogo: leitura com login, sem escrita', async () => {
    await assertSucceeds(getDoc(doc(db(ALICE), 'achievementsCatalog/semana-em-dia')));
    await assertSucceeds(getDocs(collection(db(ALICE), 'achievementsCatalog')));
    await assertFails(getDoc(doc(db(), 'achievementsCatalog/semana-em-dia')));
    await assertFails(setDoc(doc(db(ALICE), 'achievementsCatalog/novo'), { title: 'x' }));
  });

  test('documentos legais: leitura pública, sem escrita', async () => {
    await assertSucceeds(getDoc(doc(db(), 'legalDocuments/current')));
    await assertFails(setDoc(doc(db(ALICE), 'legalDocuments/current'), { termsVersion: 'x', privacyVersion: 'y' }));
    await assertFails(deleteDoc(doc(db(ALICE), 'legalDocuments/current')));
  });
});

describe('fora do mapa', () => {
  test('coleções não previstas (inclusive devices e notificationLog) são negadas', async () => {
    await assertFails(setDoc(doc(db(ALICE), 'plans/p1'), { name: 'x' }));
    await assertFails(getDoc(doc(db(ALICE), 'qualquer/coisa')));
    await assertFails(setDoc(doc(db(ALICE), `${USER}/outra/x`), { a: 1 }));
    await assertFails(setDoc(doc(db(ALICE), `${USER}/devices/inst-1`), { fcmToken: 't' }));
    await assertFails(getDoc(doc(db(ALICE), `${USER}/notificationLog/n1`)));
  });
});
