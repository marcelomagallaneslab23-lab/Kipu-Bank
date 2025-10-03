# KipuBank 🏦

## 📌 Descripción
`KipuBank` es un contrato de **bóveda personal** que permite a los usuarios:
1. **Depositar ETH** en su saldo privado.
2. **Retirar ETH** con un **límite por transacción** (inmutable, configurado en el despliegue).
3. Operar bajo un **límite global de depósitos** (`bankCap`), evitando saturación del contrato.
4. Registrar estadísticas de uso (número de depósitos/retiros).

**Enfoque en seguridad:**
✅ Patrones *Checks-Effects-Interactions*.
✅ Transferencias nativas seguras (evitando reentrancia).
✅ Errores personalizados descriptivos.
✅ Modificadores para validaciones reutilizables.
✅ Cumplimiento con [ERC-20/ETH Security Guidelines](https://consensys.github.io/smart-contract-best-practices/).

## 🛠 Configuración y Despliegue

### 📦 Requisitos
- [Remix IDE](https://remix.ethereum.org/) (recomendado para pruebas rápidas).
- Una billetera con fondos en **Sepolia/Goerli** (ej: [Metamask](https://metamask.io/)).
- API Key de [Etherscan](https://etherscan.io/) (para verificación).

### 🚀 Despliegue en Remix IDE
1. **Abre el contrato** en [Remix](https://remix.ethereum.org/):
   - Crea un nuevo archivo `/contracts/KipuBank.sol` y pega el código.
   - Compila con **Solidity 0.8.26** (habilita "Auto-compile").

2. **Configura el despliegue**:
   - Ve al tab **"Deploy & Run Transactions"**.
   - Selecciona el entorno **"Injected Provider"** (conecta Metamask).
   - Establece los parámetros del constructor:
     - `_withdrawalLimit`: Límite de retiro por transacción (ej: `0.1 ether`).
     - `_bankCap`: Capacidad máxima del banco (ej: `100 ether`).

3. **Despliega**:
   - Haz clic en **"Deploy"** y confirma la transacción en Metamask.
   - **¡Listo!** Copia la dirección del contrato desplegado.
