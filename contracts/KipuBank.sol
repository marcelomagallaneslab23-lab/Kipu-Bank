// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title KipuBank
 * @author marcelomagallanes-dev
 * @dev Contrato bancario educativo para depósitos y retiros de ETH con límites estrictos
 * @notice Este contrato es parte de un proyecto educativo para manejar bóvedas personales con ETH
 * @custom:security Este es un contrato educativo y no debe ser usado en producción sin auditoría
 */
contract KipuBank {
    /*///////////////////////
            Definición de Variables de Estado
    ///////////////////////*/

    /// @dev Límite máximo de retiro por transacción (inmutable)
    uint256 public immutable i_retiroMaximo;

    /// @dev Límite global de depósitos en el banco (inmutable)
    uint256 public immutable i_bankCap;

    /// @dev Total de ETH depositado en el banco
    uint256 public s_totalDepositos;

    /// @dev Registro de bóvedas personales por usuario (saldo en wei)
    mapping(address usuario => uint256 saldo) public s_bovedas;

    /// @dev Contador de depósitos realizados
    uint256 public s_numDepositos;

    /// @dev Contador de retiros realizados
    uint256 public s_numRetiros;

    /*///////////////////////
            Eventos
    ///////////////////////*/

    /// @dev Evento emitido cuando un usuario deposita ETH exitosamente
    /// @param usuario Dirección del depositante
    /// @param monto Cantidad depositada en wei
    event KipuBank_DepositoRealizado(address indexed usuario, uint256 monto);

    /// @dev Evento emitido cuando un usuario retira ETH exitosamente
    /// @param usuario Dirección del retirante
    /// @param monto Cantidad retirada en wei
    event KipuBank_RetiroRealizado(address indexed usuario, uint256 monto);

    /*///////////////////////
            Errores Personalizados
    ///////////////////////*/

    /// @dev Error si el depósito excede el límite global del banco
    error KipuBank_DepositoExcedeCap(uint256 intento, uint256 disponible);

    /// @dev Error si el saldo es insuficiente para el retiro solicitado
    error KipuBank_SaldoInsuficiente(uint256 solicitado, uint256 disponible);

    /// @dev Error si el retiro excede el límite por transacción
    error KipuBank_RetiroExcedeLimite(uint256 solicitado, uint256 limite);

    /// @dev Error si el depósito es cero o inválido
    error KipuBank_DepositoInvalido();

    /// @dev Error si falla la transferencia de ETH
    error KipuBank_TransferenciaFallida();

    /*///////////////////////
            Constructor
    ///////////////////////*/

    /**
     * @dev Inicializa el contrato con los límites de retiro y capacidad del banco
     * @param _retiroMaximo Límite de retiro por transacción (en wei)
     * @param _bankCap Límite total de depósitos en el banco (en wei)
     */
    constructor(uint256 _retiroMaximo, uint256 _bankCap) {
        // Validar que los límites sean mayores a cero
        if (_retiroMaximo == 0 || _bankCap == 0) revert();
        i_retiroMaximo = _retiroMaximo;
        i_bankCap = _bankCap;
    }

    /*///////////////////////
            Modificadores
    ///////////////////////*/

    /// @dev Modificador para validar que el retiro no exceda el límite por transacción
    modifier validarRetiro(uint256 _monto) {
        if (_monto > i_retiroMaximo) {
            revert KipuBank_RetiroExcedeLimite(_monto, i_retiroMaximo);
        }
        _;
    }

    /*///////////////////////
            Funciones Externas
    ///////////////////////*/

    /**
     * @dev Permite a un usuario depositar ETH en su bóveda personal
     * @notice Reverte si el monto es cero o se excede el límite global (`i_bankCap`)
     */
    function depositar() external payable {
        if (msg.value == 0) revert KipuBank_DepositoInvalido();

        uint256 nuevoTotal = s_totalDepositos + msg.value;
        if (nuevoTotal > i_bankCap) {
            revert KipuBank_DepositoExcedeCap(nuevoTotal, i_bankCap - s_totalDepositos);
        }

        // Actualizar estado (Checks-Effects-Interactions)
        s_bovedas[msg.sender] += msg.value;
        s_totalDepositos = nuevoTotal;
        s_numDepositos++;

        emit KipuBank_DepositoRealizado(msg.sender, msg.value);
    }

    /**
     * @dev Permite a un usuario retirar ETH de su bóveda personal
     * @param _monto Cantidad a retirar (en wei)
     * @notice Reverte si:
     * - El monto excede `i_retiroMaximo` (via modificador)
     * - El saldo es insuficiente
     * - Falla la transferencia de ETH
     */
    function retirar(uint256 _monto) external validarRetiro(_monto) {
        uint256 saldo = s_bovedas[msg.sender];
        if (_monto > saldo) revert KipuBank_SaldoInsuficiente(_monto, saldo);

        // Actualizar estado antes de la interacción externa
        s_bovedas[msg.sender] = saldo - _monto;
        s_totalDepositos -= _monto;
        s_numRetiros++;

        _transferirETH(msg.sender, _monto);

        emit KipuBank_RetiroRealizado(msg.sender, _monto);
    }

    /**
     * @dev Consulta el saldo de la bóveda del usuario
     * @return saldo Cantidad en wei
     */
    function consultarSaldo() external view returns (uint256) {
        return s_bovedas[msg.sender];
    }

    /*///////////////////////
            Funciones Privadas
    ///////////////////////*/

    /**
     * @dev Transfiere ETH de forma segura usando `call`
     * @param _destino Dirección receptora
     * @param _monto Cantidad a transferir (en wei)
     */
    function _transferirETH(address _destino, uint256 _monto) private {
        (bool exito, ) = _destino.call{value: _monto}("");
        if (!exito) revert KipuBank_TransferenciaFallida();
    }
}

[{"inputs":[{"internalType":"uint256","name":"_retiroMaximo","type":"uint256"},{"internalType":"uint256","name":"_bankCap","type":"uint256"}],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[{"internalType":"uint256","name":"intento","type":"uint256"},{"internalType":"uint256","name":"disponible","type":"uint256"}],"name":"KipuBank_DepositoExcedeCap","type":"error"},{"inputs":[],"name":"KipuBank_DepositoInvalido","type":"error"},{"inputs":[{"internalType":"uint256","name":"solicitado","type":"uint256"},{"internalType":"uint256","name":"limite","type":"uint256"}],"name":"KipuBank_RetiroExcedeLimite","type":"error"},{"inputs":[{"internalType":"uint256","name":"solicitado","type":"uint256"},{"internalType":"uint256","name":"disponible","type":"uint256"}],"name":"KipuBank_SaldoInsuficiente","type":"error"},{"inputs":[],"name":"KipuBank_TransferenciaFallida","type":"error"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"usuario","type":"address"},{"indexed":false,"internalType":"uint256","name":"monto","type":"uint256"}],"name":"KipuBank_DepositoRealizado","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"usuario","type":"address"},{"indexed":false,"internalType":"uint256","name":"monto","type":"uint256"}],"name":"KipuBank_RetiroRealizado","type":"event"},{"inputs":[],"name":"consultarSaldo","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"depositar","outputs":[],"stateMutability":"payable","type":"function"},{"inputs":[],"name":"i_bankCap","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"i_retiroMaximo","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_monto","type":"uint256"}],"name":"retirar","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"usuario","type":"address"}],"name":"s_bovedas","outputs":[{"internalType":"uint256","name":"saldo","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"s_numDepositos","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"s_numRetiros","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"s_totalDepositos","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}]
