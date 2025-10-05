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

    /// @notice Límite máximo de retiro por transacción (inmutable)
    /// @dev Se establece en el constructor y no puede cambiar
    uint256 public immutable i_retiroMaximo;

    /// @notice Límite global de depósitos en el banco (inmutable)
    /// @dev Se establece en el constructor y no puede cambiar
    uint256 public immutable i_bankCap;

    /// @notice Total de ETH depositado en el contrato
    /// @dev Se actualiza en cada depósito y retiro
    uint256 public s_totalDepositos;

    /// @notice Mapeo de saldos individuales por usuario
    /// @dev Cada dirección tiene su propia bóveda de ETH
    mapping(address usuario => uint256 saldo) public s_bovedas;

    /// @notice Contador de depósitos realizados
    uint256 public s_numDepositos;

    /// @notice Contador de retiros realizados
    uint256 public s_numRetiros;

    /// @dev Flag para protección contra reentrancia
    bool private locked;

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

    /// @notice Se lanza si el depósito supera el límite total del banco
    /// @param intento Monto que se intentó depositar
    /// @param disponible Monto restante disponible en el banco
    error KipuBank_DepositoExcedeCap(uint256 intento, uint256 disponible);

    /// @notice Se lanza si el usuario intenta retirar más de lo que tiene
    /// @param solicitado Monto solicitado
    /// @param disponible Saldo disponible en la bóveda
    error KipuBank_SaldoInsuficiente(uint256 solicitado, uint256 disponible);

    /// @notice Se lanza si el retiro excede el límite permitido por transacción
    /// @param solicitado Monto solicitado
    /// @param limite Límite máximo permitido
    error KipuBank_RetiroExcedeLimite(uint256 solicitado, uint256 limite);

    /// @notice Se lanza si el depósito es igual a cero
    error KipuBank_DepositoZero();

    /// @notice Se lanza si la transferencia de ETH falla
    error KipuBank_TransferenciaFallida();

    /// @notice Se lanza si los parámetros iniciales del contrato son inválidos
    error KipuBank_ParametrosInvalidos();

    /// @notice Se lanza si se detecta un intento de reentrancia
    error KipuBank_ReentranciaDetectada();

    /*///////////////////////
            Constructor
    ///////////////////////*/

    /**
     * @dev Inicializa el contrato con los límites de retiro y capacidad del banco
     * @param _retiroMaximo Límite de retiro por transacción (en wei)
     * @param _bankCap Límite total de depósitos en el banco (en wei)
     */
    constructor(uint256 _retiroMaximo, uint256 _bankCap) {
        if (_retiroMaximo == 0 || _bankCap == 0) revert KipuBank_ParametrosInvalidos();
        i_retiroMaximo = _retiroMaximo;
        i_bankCap = _bankCap;
    }

    /*///////////////////////
            Modificadores
    ///////////////////////*/

    /// @dev Modificador para validar que el retiro no exceda el límite por transacción
    /// @param _monto Monto solicitado para retirar
    modifier validarRetiro(uint256 _monto) {
        if (_monto > i_retiroMaximo) {
            revert KipuBank_RetiroExcedeLimite(_monto, i_retiroMaximo);
        }
        _;
    }

    /// @dev Modificador para prevenir ataques de reentrancia
    modifier nonReentrant() {
        if (locked) revert KipuBank_ReentranciaDetectada();
        locked = true;
        _;
    }

    /*///////////////////////
            Funciones Externas
    ///////////////////////*/

    
    /**
    * @notice Permite a un usuario depositar ETH en su bóveda personal
    * @dev Requiere que el monto sea mayor a cero y no exceda el límite global
    */
    function depositar() external payable nonReentrant {
        if (msg.value == 0) revert KipuBank_DepositoZero();

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
     * @notice Permite a un usuario retirar ETH de su bóveda personal
     * @dev Protegido contra reentrancia. Requiere saldo suficiente y que el monto no exceda el límite.
     * @param _monto Cantidad a retirar (en wei)
     */
    function retirar(uint256 _monto) external nonReentrant validarRetiro(_monto) {
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
     * @notice Consulta el saldo de la bóveda del usuario
     * @return saldo Cantidad en wei disponible en la bóveda del usuario
     */
    function consultarSaldo() external view returns (uint256 saldo) {
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




ABI:

[{"inputs":[{"internalType":"uint256","name":"_retiroMaximo","type":"uint256"},{"internalType":"uint256","name":"_bankCap","type":"uint256"}],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[{"internalType":"uint256","name":"intento","type":"uint256"},{"internalType":"uint256","name":"disponible","type":"uint256"}],"name":"KipuBank_DepositoExcedeCap","type":"error"},{"inputs":[],"name":"KipuBank_DepositoInvalido","type":"error"},{"inputs":[{"internalType":"uint256","name":"solicitado","type":"uint256"},{"internalType":"uint256","name":"limite","type":"uint256"}],"name":"KipuBank_RetiroExcedeLimite","type":"error"},{"inputs":[{"internalType":"uint256","name":"solicitado","type":"uint256"},{"internalType":"uint256","name":"disponible","type":"uint256"}],"name":"KipuBank_SaldoInsuficiente","type":"error"},{"inputs":[],"name":"KipuBank_TransferenciaFallida","type":"error"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"usuario","type":"address"},{"indexed":false,"internalType":"uint256","name":"monto","type":"uint256"}],"name":"KipuBank_DepositoRealizado","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"usuario","type":"address"},{"indexed":false,"internalType":"uint256","name":"monto","type":"uint256"}],"name":"KipuBank_RetiroRealizado","type":"event"},{"inputs":[],"name":"consultarSaldo","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"depositar","outputs":[],"stateMutability":"payable","type":"function"},{"inputs":[],"name":"i_bankCap","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"i_retiroMaximo","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_monto","type":"uint256"}],"name":"retirar","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"usuario","type":"address"}],"name":"s_bovedas","outputs":[{"internalType":"uint256","name":"saldo","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"s_numDepositos","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"s_numRetiros","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"s_totalDepositos","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}]
