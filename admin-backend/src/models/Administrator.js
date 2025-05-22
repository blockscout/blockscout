const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Administrator = sequelize.define('Administrator', {
    id: {
      type: DataTypes.BIGINT,
      primaryKey: true,
      autoIncrement: true,
    },
    role: {
      type: DataTypes.STRING,
      allowNull: false
    },
    user_id: {
      type: DataTypes.BIGINT,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id'
      }
    }
  }, {
    tableName: 'administrators',
    timestamps: true,
    createdAt: 'inserted_at',
    updatedAt: 'updated_at'
  });

  return Administrator;
};
