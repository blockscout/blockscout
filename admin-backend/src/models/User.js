const { DataTypes } = require('sequelize');
const bcrypt = require('bcryptjs');

module.exports = (sequelize) => {
  const User = sequelize.define('User', {
    id: {
      type: DataTypes.BIGINT,
      primaryKey: true,
      autoIncrement: true,
    },
    username: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true
    },
    password_hash: {
      type: DataTypes.STRING,
      allowNull: false, // Richiesto da Blockscout
      defaultValue: '!passwordless_auth!' // Valore di default per autenticazione passwordless/oauth
    },
    // Campi virtuali che non vengono salvati nel DB
    email: {
      type: DataTypes.VIRTUAL,
      get() {
        return this.username;
      },
      set(value) {
        this.setDataValue('username', value);
      }
    },
    // Campo virtuale per tenere traccia del login in memoria
    last_login_virtual: {
      type: DataTypes.VIRTUAL,
      get() {
        return this._last_login_virtual;
      },
      set(value) {
        this._last_login_virtual = value;
      }
    }
  }, {
    tableName: 'users',
    timestamps: true,
    createdAt: 'inserted_at',
    updatedAt: 'updated_at'
  });

  // Method to check password
  User.prototype.checkPassword = async function(enteredPassword) {
    if (this.password_hash) {
      return await bcrypt.compare(enteredPassword, this.password_hash);
    }
    return false;
  };

  return User;
};
