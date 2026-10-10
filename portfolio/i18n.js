const I18N = {
  es: {
    'html.lang': 'es',
    'meta.title': 'ZK-SNARKs & Privacy — Rolando Strahm',
    'meta.description':
      'Privacy pool educativo: Poseidon Merkle + Groth16 + nullifiers + relayer fee. Gas · SWC-100–136. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Proyecto',
    'nav.pillars': 'Pilares',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Proceso',
    'nav.attacks': 'Ataques',
    'nav.repos': 'Repos',
    'nav.close': '← Cerrar',

    'hero.tag': '// MÓDULO 17 · PORTFOLIO WEB3',
    'hero.title': 'ZK-SNARKS<br>&amp; PRIVACY',
    'hero.role': 'Solidity 0.8.24 · Foundry · Circom · Groth16 · Poseidon · SWC',
    'hero.sub':
      'Privacy pool educativo: commitments Poseidon, Merkle con raíces históricas, retiros Groth16, nullifiers anti double-spend y fee split para relayer. Gas documentado + matriz SWC-100–136.',
    'hero.cta1': 'Ver en GitHub',
    'hero.cta2': 'Ver en GitLab',

    'ov.eyebrow': '// 01 — CONTEXTO',
    'ov.title': 'Por qué este proyecto',
    'ov.lead':
      'Construí un <strong>PrivacyPool</strong> estilo mixer educativo: <strong>Poseidon</strong> on-chain, circuito Circom <strong>Withdraw(4)</strong>, verifier <strong>Groth16</strong>, y payout con <strong>relayer fee</strong>. El foco es <strong>nullifiers</strong> (<code>NullifierAlreadySpent</code>), <strong>raíces históricas</strong> (<code>isKnownRoot</code>), <strong>binding ZK</strong> de recipient/relayer/fee y <strong>SWC</strong> con tests que demuestran que el misuse falla.',

    'pi.eyebrow': '// 02 — TRES PILARES',
    'pi.title': 'Qué entrega el módulo',
    'p1.num': '// PILAR_01',
    'p1.title': 'Privacy Pool ZK',
    'p1.desc':
      'Deposit → prove Circom → withdraw Groth16: Merkle Poseidon, nullifiers y fee split atómico.',
    'p1.l1': 'NullifierAlreadySpent + UnknownRoot',
    'p1.l2': 'InvalidZKProof + binding públicos',
    'p1.l3': 'CEI + TransientReentrancyGuard (Cancun)',
    'p2.num': '// PILAR_02',
    'p2.title': 'Optimización de gas',
    'p2.desc':
      'Transient tstore, arrays fijos Merkle, índices packed, ETH Yul call y caches immutables.',
    'p2.l1': 'deposit mock ~133 255 gas (snapshot)',
    'p2.l2': 'verifyProof Groth16 ~215 514 (dominante e2e)',
    'p2.l3': '.gas-snapshot + optimizer 10k · via_ir off',
    'p3.num': '// PILAR_03',
    'p3.title': 'Verificación SWC',
    'p3.desc':
      'Matriz SWC-100–136, NullifierReplay, InvalidRoot, PoolProofVerification, RelayerFee, fuzz ≥ 1000.',
    'p3.l1': '0 vulnerabilidades explotables',
    'p3.l2': '30 mitigados / N/A · 6 info',
    'p3.l3': '65 tests Foundry PASS',

    'gas.eyebrow': '// 03 — OPTIMIZACIÓN DE GAS',
    'gas.title': 'Hot path barato, tradeoffs claros',
    'gas.lead':
      'Fase 7: baseline en <code>doc/GAS.md</code> y <code>.gas-snapshot</code>. Paths mock: <strong>deposit 133 255</strong>, <strong>withdraw zero-fee 221 925</strong>, <strong>relayer fee 258 391</strong>. E2E Groth16 ~<strong>2.15 M</strong> (domina pairing + Poseidon).',
    'gas.th1': 'Optimización',
    'gas.th2': 'Tradeoff / efecto',
    'gas.r1a': 'TransientReentrancyGuard (tstore)',
    'gas.r1b': 'Sin SSTORE del guard OZ; requiere Cancun',
    'gas.r2a': 'Arrays fijos bytes32[32]/[30]',
    'gas.r2b': 'Más barato que mappings en insert/root',
    'gas.r3a': 'Índices packed (1 slot)',
    'gas.r3b': 'currentRootIndex + nextIndex juntos',
    'gas.r4a': 'ETH Yul call sin returndata',
    'gas.r4b': 'Más barato que .call; EthTransferFailed',
    'gas.r5a': 'Bit ops + unchecked en _insert',
    'gas.r5b': '&amp; 1 / &gt;&gt;= vs MOD/DIV',
    'gas.r6a': 'Custom errors (PrivacyErrors)',
    'gas.r6b': 'Reverts compactos vs require strings',
    'gas.r7a': 'optimizer_runs = 10_000',
    'gas.r7b': 'via_ir off (PoseidonT3); inlining hot path',

    'swc.eyebrow': '// 04 — VERIFICACIÓN SWC',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Matriz <strong>SWC-100 → SWC-136</strong> sobre PrivacyPool, Merkle, Poseidon, Groth16Verifier y TransientReentrancyGuard. Informe: <code>doc/SWC-AUDIT.md</code>. Conclusión: <strong>0 vulnerabilidades explotables</strong> en el alcance v1. Tests: NullifierReplay · InvalidRoot · PoolProofVerification · RelayerFee.',
    'swc.s1': 'Mitigados / N/A',
    'swc.s2': 'Informativos (diseño)',
    'swc.s3': 'Vulnerables',
    'swc.th1': 'SWC clave',
    'swc.th2': 'Mitigación en el contrato',
    'swc.r101': 'Overflow: Solidity 0.8.24; fee ≤ denomination antes de resta',
    'swc.r103': 'Floating pragma: pragma solidity 0.8.24 fijo (verifier parcheado)',
    'swc.r104': 'Unchecked return: Yul call chequea success → EthTransferFailed',
    'swc.r107': 'Reentrancy: TransientReentrancyGuard + nullifier antes de ETH',
    'swc.r121': 'Replay: nullifierHashes + NullifierReplay.t.sol',
    'swc.r122': 'Proof: verifyProof + binding públicos; tests tampered',
    'swc.r123': 'Requirements: PrivacyErrors + matriz Fase 6',
    'swc.info': 'INFORMATIVO',
    'swc.i1t': 'Front-running withdraw',
    'swc.i1d':
      'Un observador puede reenviar la proof; el primero gasta el nullifier. Binding recipient/relayer/fee impide cambiar el payout sin invalidar la proof.',
    'swc.i2t': 'Malleability residual',
    'swc.i2d':
      'El gasto único depende de nullifierHash, no de unicidad de la proof. Double-spend bloqueado on-chain.',
    'swc.i3t': 'Recipient / relayer hostil',
    'swc.i3d':
      'Si recipient o relayer rechazan ETH, la tx revierte (RejectETH tests). Responsabilidad del prover al elegir addresses.',
    'swc.i4t': 'Anonymity set público',
    'swc.i4d':
      'Commitments y roots son visibles. Depth lab = 4 (set pequeño); producción tipica depth 20. Privacidad off-chain del secret.',

    'pr.eyebrow': '// 05 — PROCESO',
    'pr.title': 'Fases 0–7 cerradas',
    'pr.lead':
      'TDD por gates: Foundry + Circom, Hasher/Merkle, circuito withdraw, Groth16Verifier, deposit, withdraw+relayer, matriz SWC, gas+Deploy.',
    'ph.01': 'Setup Foundry + Hasher · Merkle',
    'ph.23': 'Circom Withdraw(4) + Groth16Verifier',
    'ph.45': 'Deposit + Withdraw · nullifier · fee',
    'ph.6': 'SWC matrix · defensive tests',
    'ph.7': 'Gas opts · Deploy · docs',
    'st.1': 'Fases',
    'st.2': 'Tests PASS',
    'st.3': 'SWC vulnerables',
    'st.4': 'Depth lab',
    'term.label': 'rolando@strahm:~/17-zk-snarks-privacy',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 65 passed · 0 failed',
    'term.3': 'cat doc/SWC-AUDIT.md | head',
    'term.4': 'Vulnerable: 0 · Informativos: 6 · Mitigados/N/A: 30',
    'term.5': 'echo status',
    'term.6': 'MODULE_17_CLOSED · GAS_SWC_CLOSED',

    'at.eyebrow': '// 06 — CAMPAÑAS DEFENSIVAS',
    'at.title': 'Defensivo, no ofensivo',
    'at.lead':
      'NullifierReplay, InvalidRoot, proof tampered, RelayerFee y RejectETH: el “éxito” del misuse es que revierte. Sin PoCs de exploit.',
    'cA.t': 'Nullifier replay',
    'cA.d': 'Mismo nullifierHash dos veces → NullifierAlreadySpent (SWC-121).',
    'cB.t': 'Unknown root',
    'cB.d': 'Root forjada o cero → UnknownRoot; raíz histórica sigue válida.',
    'cC.t': 'Proof tampered',
    'cC.d': 'a/b/c o fee/recipient alterados → InvalidZKProof (SWC-122).',
    'cD.t': 'Relayer fee',
    'cD.d': 'Split exacto; fee &gt; denomination → FeeExceeds; RejectETH → EthTransferFailed.',
    'cE.t': 'Fuzz',
    'cE.d': 'Denomination, leaves, nullifier, fee y roots ≥ 1000 runs.',

    're.eyebrow': '// 07 — CÓDIGO ABIERTO',
    're.title': 'Repositorios',
    're.lead':
      'Mismo código en GitHub y GitLab: contratos, circuitos Circom, tests, GAS.md, SWC-AUDIT.md, diagramas y Deploy.',
    're.cta': 'Contactar',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — ZK-SNARKs & Privacy · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · CIRCOM · GROTH16 · ALL_SYSTEMS_OPERATIONAL',
  },

  en: {
    'html.lang': 'en',
    'meta.title': 'ZK-SNARKs & Privacy — Rolando Strahm',
    'meta.description':
      'Educational privacy pool: Poseidon Merkle + Groth16 + nullifiers + relayer fee. Gas · SWC-100–136. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Project',
    'nav.pillars': 'Pillars',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Process',
    'nav.attacks': 'Attacks',
    'nav.repos': 'Repos',
    'nav.close': '← Close',

    'hero.tag': '// MODULE 17 · WEB3 PORTFOLIO',
    'hero.title': 'ZK-SNARKS<br>&amp; PRIVACY',
    'hero.role': 'Solidity 0.8.24 · Foundry · Circom · Groth16 · Poseidon · SWC',
    'hero.sub':
      'Educational privacy pool: Poseidon commitments, Merkle with historical roots, Groth16 withdrawals, anti double-spend nullifiers, and relayer fee split. Documented gas + SWC-100–136 matrix.',
    'hero.cta1': 'View on GitHub',
    'hero.cta2': 'View on GitLab',

    'ov.eyebrow': '// 01 — CONTEXT',
    'ov.title': 'Why this project',
    'ov.lead':
      'I built an educational mixer-style <strong>PrivacyPool</strong>: on-chain <strong>Poseidon</strong>, Circom <strong>Withdraw(4)</strong>, <strong>Groth16</strong> verifier, and <strong>relayer fee</strong> payout. Focus: <strong>nullifiers</strong> (<code>NullifierAlreadySpent</code>), <strong>historical roots</strong> (<code>isKnownRoot</code>), ZK <strong>binding</strong> of recipient/relayer/fee, and <strong>SWC</strong> tests that prove misuse reverts.',

    'pi.eyebrow': '// 02 — THREE PILLARS',
    'pi.title': 'What the module delivers',
    'p1.num': '// PILLAR_01',
    'p1.title': 'ZK Privacy Pool',
    'p1.desc':
      'Deposit → Circom prove → Groth16 withdraw: Poseidon Merkle, nullifiers, atomic fee split.',
    'p1.l1': 'NullifierAlreadySpent + UnknownRoot',
    'p1.l2': 'InvalidZKProof + public binding',
    'p1.l3': 'CEI + TransientReentrancyGuard (Cancun)',
    'p2.num': '// PILLAR_02',
    'p2.title': 'Gas optimization',
    'p2.desc':
      'Transient tstore, fixed Merkle arrays, packed indices, Yul ETH call, immutable caches.',
    'p2.l1': 'mock deposit ~133 255 gas (snapshot)',
    'p2.l2': 'Groth16 verifyProof ~215 514 (e2e dominant)',
    'p2.l3': '.gas-snapshot + optimizer 10k · via_ir off',
    'p3.num': '// PILLAR_03',
    'p3.title': 'SWC verification',
    'p3.desc':
      'SWC-100–136 matrix, NullifierReplay, InvalidRoot, PoolProofVerification, RelayerFee, fuzz ≥ 1000.',
    'p3.l1': '0 exploitable vulnerabilities',
    'p3.l2': '30 mitigated / N/A · 6 info',
    'p3.l3': '65 Foundry tests PASS',

    'gas.eyebrow': '// 03 — GAS OPTIMIZATION',
    'gas.title': 'Cheap hot path, clear tradeoffs',
    'gas.lead':
      'Phase 7: baseline in <code>doc/GAS.md</code> and <code>.gas-snapshot</code>. Mock paths: <strong>deposit 133 255</strong>, <strong>withdraw zero-fee 221 925</strong>, <strong>relayer fee 258 391</strong>. Groth16 e2e ~<strong>2.15 M</strong> (pairing + Poseidon dominate).',
    'gas.th1': 'Optimization',
    'gas.th2': 'Tradeoff / effect',
    'gas.r1a': 'TransientReentrancyGuard (tstore)',
    'gas.r1b': 'No OZ guard SSTORE; requires Cancun',
    'gas.r2a': 'Fixed arrays bytes32[32]/[30]',
    'gas.r2b': 'Cheaper than mappings on insert/root',
    'gas.r3a': 'Packed indices (1 slot)',
    'gas.r3b': 'currentRootIndex + nextIndex together',
    'gas.r4a': 'Yul ETH call without returndata',
    'gas.r4b': 'Cheaper than .call; EthTransferFailed',
    'gas.r5a': 'Bit ops + unchecked in _insert',
    'gas.r5b': '&amp; 1 / &gt;&gt;= vs MOD/DIV',
    'gas.r6a': 'Custom errors (PrivacyErrors)',
    'gas.r6b': 'Compact reverts vs require strings',
    'gas.r7a': 'optimizer_runs = 10_000',
    'gas.r7b': 'via_ir off (PoseidonT3); hot-path inlining',

    'swc.eyebrow': '// 04 — SWC VERIFICATION',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      '<strong>SWC-100 → SWC-136</strong> matrix over PrivacyPool, Merkle, Poseidon, Groth16Verifier, and TransientReentrancyGuard. Report: <code>doc/SWC-AUDIT.md</code>. Conclusion: <strong>0 exploitable vulnerabilities</strong> in v1 scope. Tests: NullifierReplay · InvalidRoot · PoolProofVerification · RelayerFee.',
    'swc.s1': 'Mitigated / N/A',
    'swc.s2': 'Informational (design)',
    'swc.s3': 'Vulnerable',
    'swc.th1': 'Key SWC',
    'swc.th2': 'Mitigation in the contract',
    'swc.r101': 'Overflow: Solidity 0.8.24; fee ≤ denomination before subtract',
    'swc.r103': 'Floating pragma: fixed pragma solidity 0.8.24 (patched verifier)',
    'swc.r104': 'Unchecked return: Yul call checks success → EthTransferFailed',
    'swc.r107': 'Reentrancy: TransientReentrancyGuard + nullifier before ETH',
    'swc.r121': 'Replay: nullifierHashes + NullifierReplay.t.sol',
    'swc.r122': 'Proof: verifyProof + public binding; tampered tests',
    'swc.r123': 'Requirements: PrivacyErrors + Phase 6 matrix',
    'swc.info': 'INFORMATIONAL',
    'swc.i1t': 'Withdraw front-running',
    'swc.i1d':
      'An observer can rebroadcast the proof; the first spend burns the nullifier. Binding recipient/relayer/fee prevents payout changes without invalidating the proof.',
    'swc.i2t': 'Residual malleability',
    'swc.i2d':
      'Unique spend depends on nullifierHash, not proof uniqueness. Double-spend blocked on-chain.',
    'swc.i3t': 'Hostile recipient / relayer',
    'swc.i3d':
      'If recipient or relayer reject ETH, the tx reverts (RejectETH tests). Prover responsibility when choosing addresses.',
    'swc.i4t': 'Public anonymity set',
    'swc.i4d':
      'Commitments and roots are visible. Lab depth = 4 (small set); production often depth 20. Off-chain secret privacy.',

    'pr.eyebrow': '// 05 — PROCESS',
    'pr.title': 'Phases 0–7 closed',
    'pr.lead':
      'TDD by gates: Foundry + Circom, Hasher/Merkle, withdraw circuit, Groth16Verifier, deposit, withdraw+relayer, SWC matrix, gas+Deploy.',
    'ph.01': 'Foundry setup + Hasher · Merkle',
    'ph.23': 'Circom Withdraw(4) + Groth16Verifier',
    'ph.45': 'Deposit + Withdraw · nullifier · fee',
    'ph.6': 'SWC matrix · defensive tests',
    'ph.7': 'Gas opts · Deploy · docs',
    'st.1': 'Phases',
    'st.2': 'Tests PASS',
    'st.3': 'SWC vulnerable',
    'st.4': 'Lab depth',
    'term.label': 'rolando@strahm:~/17-zk-snarks-privacy',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 65 passed · 0 failed',
    'term.3': 'cat doc/SWC-AUDIT.md | head',
    'term.4': 'Vulnerable: 0 · Informational: 6 · Mitigated/N/A: 30',
    'term.5': 'echo status',
    'term.6': 'MODULE_17_CLOSED · GAS_SWC_CLOSED',

    'at.eyebrow': '// 06 — DEFENSIVE CAMPAIGNS',
    'at.title': 'Defensive, not offensive',
    'at.lead':
      'NullifierReplay, InvalidRoot, tampered proof, RelayerFee, and RejectETH: misuse “success” means revert. No exploit PoCs.',
    'cA.t': 'Nullifier replay',
    'cA.d': 'Same nullifierHash twice → NullifierAlreadySpent (SWC-121).',
    'cB.t': 'Unknown root',
    'cB.d': 'Forged or zero root → UnknownRoot; historical root still valid.',
    'cC.t': 'Tampered proof',
    'cC.d': 'Altered a/b/c or fee/recipient → InvalidZKProof (SWC-122).',
    'cD.t': 'Relayer fee',
    'cD.d': 'Exact split; fee &gt; denomination → FeeExceeds; RejectETH → EthTransferFailed.',
    'cE.t': 'Fuzz',
    'cE.d': 'Denomination, leaves, nullifier, fee, and roots ≥ 1000 runs.',

    're.eyebrow': '// 07 — OPEN SOURCE',
    're.title': 'Repositories',
    're.lead':
      'Same code on GitHub and GitLab: contracts, Circom circuits, tests, GAS.md, SWC-AUDIT.md, diagrams, and Deploy.',
    're.cta': 'Contact',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — ZK-SNARKs & Privacy · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · CIRCOM · GROTH16 · ALL_SYSTEMS_OPERATIONAL',
  },
};

(function () {
  const STORAGE_KEY = 'portfolio-lang';
  const params = new URLSearchParams(window.location.search);
  let lang = params.get('lang') || localStorage.getItem(STORAGE_KEY) || 'es';
  if (!I18N[lang]) lang = 'es';

  function apply(langCode) {
    const dict = I18N[langCode] || I18N.es;
    document.documentElement.lang = dict['html.lang'] || langCode;

    const title = document.querySelector('title');
    if (title && dict['meta.title']) title.textContent = dict['meta.title'];

    const metaDesc = document.querySelector('meta[name="description"]');
    if (metaDesc && dict['meta.description']) metaDesc.setAttribute('content', dict['meta.description']);

    document.querySelectorAll('[data-i18n]').forEach((el) => {
      const key = el.getAttribute('data-i18n');
      const val = dict[key];
      if (val == null) return;
      if (el.hasAttribute('data-i18n-html')) el.innerHTML = val;
      else el.textContent = val;
    });

    document.querySelectorAll('.lang-btn').forEach((btn) => {
      btn.classList.toggle('active', btn.getAttribute('data-lang') === langCode);
    });

    localStorage.setItem(STORAGE_KEY, langCode);
  }

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.addEventListener('click', () => apply(btn.getAttribute('data-lang')));
  });

  apply(lang);
})();
